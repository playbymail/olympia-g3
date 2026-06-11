// Copyright (c) 2026 Michael D Henderson. All rights reserved.

//
// Created by Michael Henderson on 1/25/26.
//

#ifndef OLYMPIA_LISTS_H
#define OLYMPIA_LISTS_H

#define		ILIST_ALLOC	6	/* doubles with each realloc */

// 'accept_ents_list' reallocing array definitions
typedef struct accept_ent **accept_ents_list;
extern void accept_ents_append(accept_ents_list *l, struct accept_ent *n);
extern void accept_ents_clear(accept_ents_list *l);
extern accept_ents_list accept_ents_copy(accept_ents_list l);
extern void accept_ents_delete(accept_ents_list *l, int i);
extern int accept_ents_len(accept_ents_list l);
extern int accept_ents_lookup(accept_ents_list l, struct accept_ent *n);
extern void accept_ents_prepend(accept_ents_list *l, struct accept_ent *n);
extern void accept_ents_reclaim(accept_ents_list *l);
extern void accept_ents_rem_value(accept_ents_list *l, struct accept_ent *n);
extern void accept_ents_scramble(accept_ents_list l);
extern void accept_ents_shuffle(accept_ents_list l);
extern void accept_ents_test(void);

// 'admits_list' reallocing array definitions
typedef struct admit **admits_list;
extern void admits_append(admits_list *l, struct admit *n);
extern void admits_clear(admits_list *l);
extern admits_list admits_copy(admits_list l);
extern void admits_delete(admits_list *l, int i);
extern int admits_len(admits_list l);
extern int admits_lookup(admits_list l, struct admit *n);
extern void admits_prepend(admits_list *l, struct admit *n);
extern void admits_reclaim(admits_list *l);
extern void admits_rem_value(admits_list *l, struct admit *n);
extern void admits_scramble(admits_list l);
extern void admits_shuffle(admits_list l);
extern void admits_test(void);

// 'cstrings_list' reallocing array definitions
typedef char **cstrings_list;
extern void cstrings_append(cstrings_list *l, char *n);
extern void cstrings_clear(cstrings_list *l);
extern cstrings_list cstrings_copy(cstrings_list l);
extern void cstrings_delete(cstrings_list *l, int i);
extern int cstrings_len(cstrings_list l);
extern int cstrings_lookup(cstrings_list l, char *n);
extern void cstrings_prepend(cstrings_list *l, char *n);
extern void cstrings_reclaim(cstrings_list *l);
extern void cstrings_rem_value(cstrings_list *l, char *n);
extern void cstrings_scramble(cstrings_list l);
extern void cstrings_shuffle(cstrings_list l);
extern void cstrings_test(void);

// 'effects_list' reallocing array definitions
typedef struct effect **effects_list;
extern void effects_append(effects_list *l, struct effect *n);
extern void effects_clear(effects_list *l);
extern effects_list effects_copy(effects_list l);
extern void effects_delete(effects_list *l, int i);
extern int effects_len(effects_list l);
extern int effects_lookup(effects_list l, struct effect *n);
extern void effects_prepend(effects_list *l, struct effect *n);
extern void effects_reclaim(effects_list *l);
extern void effects_rem_value(effects_list *l, struct effect *n);
extern void effects_scramble(effects_list l);
extern void effects_shuffle(effects_list l);
extern void effects_test(void);

// 'entity_builds_list' reallocing array definitions
typedef struct entity_build **entity_builds_list;
extern void entity_builds_append(entity_builds_list *l, struct entity_build *n);
extern void entity_builds_clear(entity_builds_list *l);
extern entity_builds_list entity_builds_copy(entity_builds_list l);
extern void entity_builds_delete(entity_builds_list *l, int i);
extern int entity_builds_len(entity_builds_list l);
extern int entity_builds_lookup(entity_builds_list l, struct entity_build *n);
extern void entity_builds_prepend(entity_builds_list *l, struct entity_build *n);
extern void entity_builds_reclaim(entity_builds_list *l);
extern void entity_builds_rem_value(entity_builds_list *l, struct entity_build *n);
extern void entity_builds_scramble(entity_builds_list l);
extern void entity_builds_shuffle(entity_builds_list l);
extern void entity_builds_test(void);

// 'exit_views_list' reallocing array definitions
typedef struct exit_view **exit_views_list;
extern void exit_views_append(exit_views_list *l, struct exit_view *n);
extern void exit_views_clear(exit_views_list *l);
extern exit_views_list exit_views_copy(exit_views_list l);
extern void exit_views_delete(exit_views_list *l, int i);
extern int exit_views_len(exit_views_list l);
extern int exit_views_lookup(exit_views_list l, struct exit_view *n);
extern void exit_views_prepend(exit_views_list *l, struct exit_view *n);
extern void exit_views_reclaim(exit_views_list *l);
extern void exit_views_rem_value(exit_views_list *l, struct exit_view *n);
extern void exit_views_scramble(exit_views_list l);
extern void exit_views_shuffle(exit_views_list l);
extern void exit_views_test(void);

// 'fights_list' reallocing array definitions
typedef struct fight **fights_list;
extern void fights_append(fights_list *l, struct fight *n);
extern void fights_clear(fights_list *l);
extern fights_list fights_copy(fights_list l);
extern void fights_delete(fights_list *l, int i);
extern int fights_len(fights_list l);
extern int fights_lookup(fights_list l, struct fight *n);
extern void fights_prepend(fights_list *l, struct fight *n);
extern void fights_reclaim(fights_list *l);
extern void fights_rem_value(fights_list *l, struct fight *n);
extern void fights_scramble(fights_list l);
extern void fights_shuffle(fights_list l);
extern void fights_test(void);

// 'flag_ents_list' reallocing array definitions
typedef struct flag_ent **flag_ents_list;
extern void flag_ents_append(flag_ents_list *l, struct flag_ent *n);
extern void flag_ents_clear(flag_ents_list *l);
extern flag_ents_list flag_ents_copy(flag_ents_list l);
extern void flag_ents_delete(flag_ents_list *l, int i);
extern int flag_ents_len(flag_ents_list l);
extern int flag_ents_lookup(flag_ents_list l, struct flag_ent *n);
extern void flag_ents_prepend(flag_ents_list *l, struct flag_ent *n);
extern void flag_ents_reclaim(flag_ents_list *l);
extern void flag_ents_rem_value(flag_ents_list *l, struct flag_ent *n);
extern void flag_ents_scramble(flag_ents_list l);
extern void flag_ents_shuffle(flag_ents_list l);
extern void flag_ents_test(void);

// 'ilist' reallocing array definitions
typedef int *ilist;
extern void ilist_add(ilist *l, int n);
extern void ilist_append(ilist *l, int n);
extern void ilist_clear(ilist *l);
extern ilist ilist_copy(ilist l);
extern void ilist_delete(ilist *l, int i);
extern int ilist_len(ilist l);
extern int ilist_lookup(ilist l, int n);
extern void ilist_insert(ilist *l, int pos, int n);
extern void ilist_prepend(ilist *l, int n);
extern void ilist_reclaim(ilist *l);
extern void ilist_rem_value(ilist *l, int n);
extern void ilist_rem_value_uniq(ilist *l, int n);
extern void ilist_scramble(ilist l);
extern void ilist_shuffle(ilist l);
extern void ilist_test(void);

// 'item_ents_list' reallocing array definitions
typedef struct item_ent **item_ents_list;
extern void item_ents_append(item_ents_list *l, struct item_ent *n);
extern void item_ents_clear(item_ents_list *l);
extern item_ents_list item_ents_copy(item_ents_list l);
extern void item_ents_delete(item_ents_list *l, int i);
extern int item_ents_len(item_ents_list l);
extern int item_ents_lookup(item_ents_list l, struct item_ent *n);
extern void item_ents_prepend(item_ents_list *l, struct item_ent *n);
extern void item_ents_reclaim(item_ents_list *l);
extern void item_ents_rem_value(item_ents_list *l, struct item_ent *n);
extern void item_ents_scramble(item_ents_list l);
extern void item_ents_shuffle(item_ents_list l);
extern void item_ents_test(void);

// 'orders_list' reallocing array definitions
typedef struct order_list **orders_list;
extern void orders_append(orders_list *l, struct order_list *n);
extern void orders_clear(orders_list *l);
extern orders_list orders_copy(orders_list l);
extern void orders_delete(orders_list *l, int i);
extern int orders_len(orders_list l);
extern int orders_lookup(orders_list l, struct order_list *n);
extern void orders_prepend(orders_list *l, struct order_list *n);
extern void orders_reclaim(orders_list *l);
extern void orders_rem_value(orders_list *l, struct order_list *n);
extern void orders_scramble(orders_list l);
extern void orders_shuffle(orders_list l);
extern void orders_test(void);

// 'plist' reallocing array definitions
typedef void **plist;
extern void plist_append(plist *l, void *n);
extern void plist_clear(plist *l);
extern plist plist_copy(plist l);
extern void plist_delete(plist *l, int i);
extern int plist_len(plist l);
extern int plist_lookup(plist l, void *n);
extern void plist_insert(plist *l, int pos, void *n);
extern void plist_prepend(plist *l, void *n);
extern void plist_reclaim(plist *l);
extern void plist_rem_value(plist *l, void *n);
extern void plist_rem_value_uniq(plist *l, void *n);
extern void plist_scramble(plist l);
extern void plist_shuffle(plist l);
extern void plist_test(void);

// 'req_ents_list' reallocing array definitions
typedef struct req_ent **req_ents_list;
extern void req_ents_append(req_ents_list *l, struct req_ent *n);
extern void req_ents_clear(req_ents_list *l);
extern req_ents_list req_ents_copy(req_ents_list l);
extern void req_ents_delete(req_ents_list *l, int i);
extern int req_ents_len(req_ents_list l);
extern int req_ents_lookup(req_ents_list l, struct req_ent *n);
extern void req_ents_prepend(req_ents_list *l, struct req_ent *n);
extern void req_ents_reclaim(req_ents_list *l);
extern void req_ents_rem_value(req_ents_list *l, struct req_ent *n);
extern void req_ents_scramble(req_ents_list l);
extern void req_ents_shuffle(req_ents_list l);
extern void req_ents_test(void);

// 'roads_list' reallocing array definitions
typedef struct road **roads_list;
extern void roads_append(roads_list *l, struct road *n);
extern void roads_clear(roads_list *l);
extern roads_list roads_copy(roads_list l);
extern void roads_delete(roads_list *l, int i);
extern int roads_len(roads_list l);
extern int roads_lookup(roads_list l, struct road *n);
extern void roads_prepend(roads_list *l, struct road *n);
extern void roads_reclaim(roads_list *l);
extern void roads_rem_value(roads_list *l, struct road *n);
extern void roads_scramble(roads_list l);
extern void roads_shuffle(roads_list l);
extern void roads_test(void);

// 'skill_ents_list' reallocing array definitions
typedef struct skill_ent **skill_ents_list;
extern void skill_ents_append(skill_ents_list *l, struct skill_ent *n);
extern void skill_ents_clear(skill_ents_list *l);
extern skill_ents_list skill_ents_copy(skill_ents_list l);
extern void skill_ents_delete(skill_ents_list *l, int i);
extern int skill_ents_len(skill_ents_list l);
extern int skill_ents_lookup(skill_ents_list l, struct skill_ent *n);
extern void skill_ents_prepend(skill_ents_list *l, struct skill_ent *n);
extern void skill_ents_reclaim(skill_ents_list *l);
extern void skill_ents_rem_value(skill_ents_list *l, struct skill_ent *n);
extern void skill_ents_scramble(skill_ents_list l);
extern void skill_ents_shuffle(skill_ents_list l);
extern void skill_ents_test(void);

// 'tiles_list' reallocing array definitions
typedef struct tile **tiles_list;
extern void tiles_append(tiles_list *l, struct tile *n);
extern void tiles_clear(tiles_list *l);
extern tiles_list tiles_copy(tiles_list l);
extern void tiles_delete(tiles_list *l, int i);
extern int tiles_len(tiles_list l);
extern int tiles_lookup(tiles_list l, struct tile *n);
extern void tiles_prepend(tiles_list *l, struct tile *n);
extern void tiles_reclaim(tiles_list *l);
extern void tiles_rem_value(tiles_list *l, struct tile *n);
extern void tiles_scramble(tiles_list l);
extern void tiles_shuffle(tiles_list l);
extern void tiles_test(void);

// 'trades_list' reallocing array definitions
typedef struct trade **trades_list;
extern void trades_append(trades_list *l, struct trade *n);
extern void trades_clear(trades_list *l);
extern trades_list trades_copy(trades_list l);
extern void trades_delete(trades_list *l, int i);
extern int trades_len(trades_list l);
extern int trades_lookup(trades_list l, struct trade *n);
extern void trades_prepend(trades_list *l, struct trade *n);
extern void trades_reclaim(trades_list *l);
extern void trades_rem_value(trades_list *l, struct trade *n);
extern void trades_scramble(trades_list l);
extern void trades_shuffle(trades_list l);
extern void trades_test(void);

// 'wait_args_list' reallocing array definitions
typedef struct wait_arg **wait_args_list;
extern void wait_args_append(wait_args_list *l, struct wait_arg *n);
extern void wait_args_clear(wait_args_list *l);
extern wait_args_list wait_args_copy(wait_args_list l);
extern void wait_args_delete(wait_args_list *l, int i);
extern int wait_args_len(wait_args_list l);
extern int wait_args_lookup(wait_args_list l, struct wait_arg *n);
extern void wait_args_prepend(wait_args_list *l, struct wait_arg *n);
extern void wait_args_reclaim(wait_args_list *l);
extern void wait_args_rem_value(wait_args_list *l, struct wait_arg *n);
extern void wait_args_scramble(wait_args_list l);
extern void wait_args_shuffle(wait_args_list l);
extern void wait_args_test(void);

#endif //OLYMPIA_LISTS_H
