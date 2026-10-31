#define _GNU_SOURCE
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#define KEYS 200
#define REUSE_KEYS 8

static pthread_key_t keys[KEYS];
static volatile int dtor_calls;

static void dtor(void *p) {
    (void)p;
    dtor_calls++;
}

static void *set_tls(void *arg) {
    pthread_setspecific(*(pthread_key_t *)arg, (void *)0x42);
    return NULL;
}

static void *thread_value(void *arg) {
    pthread_key_t key = *(pthread_key_t *)arg;
    pthread_setspecific(key, (void *)0x99);
    return pthread_getspecific(key);
}

int main(void) {
    for (int i = 0; i < KEYS; i++) {
        if (pthread_key_create(&keys[i], NULL) != 0) {
            fprintf(stderr, "key_create failed at %d\n", i);
            return 1;
        }
        if (pthread_setspecific(keys[i], (void *)(long)(i + 1)) != 0) {
            fprintf(stderr, "setspecific failed at %d\n", i);
            return 1;
        }
    }
    for (int i = 0; i < KEYS; i++) {
        if (pthread_getspecific(keys[i]) != (void *)(long)(i + 1)) {
            fprintf(stderr, "getspecific mismatch at %d\n", i);
            return 1;
        }
    }
    for (int i = 0; i < KEYS; i++) {
        if (pthread_key_delete(keys[i]) != 0) {
            fprintf(stderr, "key_delete failed at %d\n", i);
            return 1;
        }
    }

    for (int i = 0; i < REUSE_KEYS; i++) {
        if (pthread_key_create(&keys[i], NULL) != 0) {
            fprintf(stderr, "reuse key_create failed at %d\n", i);
            return 1;
        }
        if (pthread_getspecific(keys[i]) != NULL) {
            fprintf(stderr, "stale value after reuse at %d\n", i);
            return 1;
        }
    }

    pthread_key_t dtor_key;
    if (pthread_key_create(&dtor_key, dtor) != 0) {
        fprintf(stderr, "dtor key_create failed\n");
        return 1;
    }
    pthread_t th;
    if (pthread_create(&th, NULL, set_tls, &dtor_key) != 0) {
        fprintf(stderr, "pthread_create failed\n");
        return 1;
    }
    pthread_join(th, NULL);
    if (dtor_calls != 1) {
        fprintf(stderr, "destructor calls: %d\n", dtor_calls);
        return 1;
    }

    pthread_t th2;
    void *got = NULL;
    if (pthread_create(&th2, NULL, thread_value, &keys[0]) != 0) {
        fprintf(stderr, "pthread_create 2 failed\n");
        return 1;
    }
    pthread_join(th2, &got);
    if (got != (void *)0x99) {
        fprintf(stderr, "thread-local value mismatch\n");
        return 1;
    }

    puts("tls-shim ok");
    return 0;
}
