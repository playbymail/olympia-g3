// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/25/26.
//

#ifndef OLYMPIA_LEGACY_H
#define OLYMPIA_LEGACY_H

/* BUGFIX (modernization): forward declarations */
// void call_init_routines(void);
void compute_civ_levels(void);
void load_db(void);
void load_seed(char *fnam);
void post_production(void);
void stage(char *s);

/* BUGFIX (modernization): use varargs */
void html(int who, const char *format, ...)
    __attribute__((format(printf, 2, 3)));
void out(int who, const char *format, ...)
    __attribute__((format(printf, 2, 3)));
char *sout(const char *format, ...)
    __attribute__((format(printf, 1, 2)));
void wiout(int who, int ind, const char *format, ...)
    __attribute__((format(printf, 3, 4)));
void wout(int who, const char *format, ...)
    __attribute__((format(printf, 2, 3)));

#endif //OLYMPIA_LEGACY_H