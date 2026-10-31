// S3 bootstrap-only compatibility shim: raise the pthread-key ceiling for
// mrustc-built rustc binaries on stock musl (128 keys) to glibc parity.
//
// Root cause: mrustc does not set the `target_thread_local` cfg, so every
// `thread_local!` in std/rustc lowers to a pthread key. The seed rustc needs
// ~130 keys; stock musl allows 128 and key #130 aborts the process
// ("out of TLS keys"). StageX fixes this in their own musl build
// (PTHREAD_KEYS_MAX 128 -> 256); the host libc here cannot be rebuilt, so
// this preload supplies a 1024-slot table backed by a single real key.
//
// Scope: seed stages only (running mrustc-built rustc as a compiler in S3
// run_rustc and the S4 x.py predecessor step). Retired once a native-TLS
// compiler (1.91.1+) is the compiler. Never part of any delivered toolchain.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define SHIM_KEYS_MAX 1024

typedef int (*key_create_fn)(pthread_key_t *, void (*)(void *));
typedef void *(*getspec_fn)(pthread_key_t);
typedef int (*setspec_fn)(pthread_key_t, const void *);
typedef int (*key_delete_fn)(pthread_key_t);

struct slot {
    int used;
    unsigned gen;
    void (*dtor)(void *);
};
static struct slot slots[SHIM_KEYS_MAX];
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_key_t backing;
static pthread_once_t init_once = PTHREAD_ONCE_INIT;

// Per-thread values, tagged with the slot generation so a deleted-and-reused
// key never fires a stale entry's destructor or leaks a stale read.
struct entry {
    void *val;
    unsigned gen;
};

static void thread_fini(void *vals_ptr) {
    struct entry *vals = vals_ptr;
    if (!vals)
        return;
    pthread_mutex_lock(&lock);
    for (int i = 0; i < SHIM_KEYS_MAX; i++) {
        if (vals[i].val && vals[i].gen == slots[i].gen && slots[i].used && slots[i].dtor) {
            void (*d)(void *) = slots[i].dtor;
            void *v = vals[i].val;
            vals[i].val = 0;
            pthread_mutex_unlock(&lock);
            d(v);
            pthread_mutex_lock(&lock);
        }
    }
    pthread_mutex_unlock(&lock);
    free(vals);
}

static void do_init(void) {
    key_create_fn real_create = (key_create_fn)dlsym(RTLD_NEXT, "pthread_key_create");
    // One real key per process backs the whole table.
    if (real_create(&backing, thread_fini) != 0) {
        const char msg[] = "tlskeys: backing key failed\n";
        write(STDERR_FILENO, msg, sizeof(msg) - 1);
        _exit(127);
    }
}

static struct entry *myvals(void) {
    getspec_fn real_get = (getspec_fn)dlsym(RTLD_NEXT, "pthread_getspecific");
    setspec_fn real_set = (setspec_fn)dlsym(RTLD_NEXT, "pthread_setspecific");
    struct entry *v = real_get(backing);
    if (!v) {
        v = calloc(SHIM_KEYS_MAX, sizeof(struct entry));
        if (!v) {
            const char msg[] = "tlskeys: out of memory\n";
            write(STDERR_FILENO, msg, sizeof(msg) - 1);
            _exit(127);
        }
        real_set(backing, v);
    }
    return v;
}

int pthread_key_create(pthread_key_t *key, void (*dtor)(void *)) {
    pthread_once(&init_once, do_init);
    pthread_mutex_lock(&lock);
    for (int i = 0; i < SHIM_KEYS_MAX; i++) {
        if (!slots[i].used) {
            slots[i].used = 1;
            slots[i].dtor = dtor;
            *key = (pthread_key_t)(i + 1);
            pthread_mutex_unlock(&lock);
            return 0;
        }
    }
    pthread_mutex_unlock(&lock);
    return 11; // EAGAIN, same as musl when exhausted
}

void *pthread_getspecific(pthread_key_t k) {
    unsigned i = (unsigned)k;
    if (i == 0 || i > (unsigned)SHIM_KEYS_MAX)
        return 0;
    pthread_once(&init_once, do_init);
    struct entry *vals = myvals();
    if (!slots[i - 1].used || vals[i - 1].gen != slots[i - 1].gen)
        return 0;
    return vals[i - 1].val;
}

int pthread_setspecific(pthread_key_t k, const void *v) {
    unsigned i = (unsigned)k;
    if (i == 0 || i > (unsigned)SHIM_KEYS_MAX) {
        // Not ours: pass through (e.g. backing key itself, libc internals).
        setspec_fn real_set = (setspec_fn)dlsym(RTLD_NEXT, "pthread_setspecific");
        return real_set(k, v);
    }
    pthread_once(&init_once, do_init);
    pthread_mutex_lock(&lock);
    int live = slots[i - 1].used;
    unsigned g = slots[i - 1].gen;
    pthread_mutex_unlock(&lock);
    if (!live)
        return 22; // EINVAL: setting a deleted key
    struct entry *vals = myvals();
    vals[i - 1].val = (void *)v;
    vals[i - 1].gen = g;
    return 0;
}

int pthread_key_delete(pthread_key_t k) {
    unsigned i = (unsigned)k;
    if (i == 0 || i > (unsigned)SHIM_KEYS_MAX) {
        key_delete_fn real_del = (key_delete_fn)dlsym(RTLD_NEXT, "pthread_key_delete");
        return real_del(k);
    }
    pthread_mutex_lock(&lock);
    if (!slots[i - 1].used) {
        pthread_mutex_unlock(&lock);
        return 22; // EINVAL
    }
    slots[i - 1].used = 0;
    slots[i - 1].dtor = 0;
    slots[i - 1].gen++; // orphan all live per-thread entries for this key
    pthread_mutex_unlock(&lock);
    return 0;
}
