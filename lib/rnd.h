/*
 *  Shared MD5-based random number generator (lib/rnd.c).
 *
 *  Used by both the map generator (mapgen-g3) and the standalone island
 *  generator (island-g3).  Declares the RNG entry points the two programs
 *  call; rnd.c defines them on top of an embedded MD5 implementation.
 */

#ifndef OLYMPIA_RND_H
#define OLYMPIA_RND_H

extern void MD5(void *dest, void *orig, int len);
extern void load_seed(char *fnam);
extern void save_seed(char *fnam);
extern int rnd(int low, int high);
extern int md5_int(int a, int b, int c, int d);

#endif /* OLYMPIA_RND_H */
