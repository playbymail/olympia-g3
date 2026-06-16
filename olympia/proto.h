#ifndef OLY_PROTO_H
#define OLY_PROTO_H

/*
 *  proto.h -- generated ANSI prototypes for cross-file (non-static)
 *  functions, extracted from their definitions (Phase 4 modernization).
 *  Eliminates -Wmissing-prototypes at the definitions and
 *  -Wimplicit-function-declaration at the call sites.
 */

/*
 *  Forward-declare structs defined privately inside a single .c file (not in
 *  any header), so the prototypes below bind to the real file-scope tag rather
 *  than a distinct prototype-scope tag (C's prototype-scope rule).
 */
struct build_ent;
struct fight;
struct harvest;
struct make;
struct wield;
struct rng_stream;	/* lib/rng.h -- pointer-only in prototypes below */

/* olympia/add.c */
extern void add_new_players(void);
extern void new_player_list(void);
extern void new_player_top(int mail);
extern void rename_act_join_files(void);

/* olympia/adv.c */
extern int d_teleport_item(struct command *c);
extern int d_trance(struct command *c);
extern int v_teleport_item(struct command *c);
extern int v_trance(struct command *c);

/* olympia/alchem.c */
extern int d_brew_death(struct command *c);
extern int d_brew_heal(struct command *c);
extern int d_brew_slave(struct command *c);
extern int d_lead_to_gold(struct command *c);
extern int new_potion(int who);
extern int v_brew(struct command *c);
extern int v_lead_to_gold(struct command *c);
extern int v_use_death(struct command *c);
extern int v_use_heal(struct command *c);
extern int v_use_slave(struct command *c);

/* olympia/art.c */
extern int create_npc_token(int who);
extern int d_cloak_creat(struct command *c);
extern int d_cloak_reg(struct command *c);
extern int d_curse_noncreat(struct command *c);
extern int d_destroy_art(struct command *c);
extern int d_forge_art_x(struct command *c);
extern int d_forge_aura(struct command *c);
extern int d_forge_palantir(struct command *c);
extern int d_rem_art_cloak(struct command *c);
extern int d_show_art_creat(struct command *c);
extern int d_show_art_reg(struct command *c);
extern int d_use_palantir(struct command *c);
extern int max_current_aura(int who);
extern int new_orb(int who);
extern int new_suffuse_ring(int who);
extern int token_player(int owner);
extern int v_cloak_creat(struct command *c);
extern int v_cloak_reg(struct command *c);
extern int v_curse_noncreat(struct command *c);
extern int v_destroy_art(struct command *c);
extern int v_forge_art_x(struct command *c);
extern int v_forge_aura(struct command *c);
extern int v_forge_palantir(struct command *c);
extern int v_rem_art_cloak(struct command *c);
extern int v_show_art_creat(struct command *c);
extern int v_show_art_reg(struct command *c);
extern int v_suffuse_ring(struct command *c, int kind);
extern int v_use_orb(struct command *c);
extern int v_use_palantir(struct command *c);
extern void check_token_units(void);
extern void limit_cur_aura(int who);
extern void move_token(int item, int from, int to);

/* olympia/basic.c */
extern int d_adv_med(struct command *c);
extern int d_detect_abil(struct command *c);
extern int d_dispel_abil(struct command *c);
extern int d_heal(struct command *c);
extern int d_hinder_med(struct command *c);
extern int d_meditate(struct command *c);
extern int d_quick_cast(struct command *c);
extern int d_reveal_mage(struct command *c);
extern int d_save_quick(struct command *c);
extern int d_shroud_abil(struct command *c);
extern int d_tap_health(struct command *c);
extern int d_view_aura(struct command *c);
extern int d_write_spell(struct command *c);
extern int new_scroll(int who);
extern int v_adv_med(struct command *c);
extern int v_appear_common(struct command *c);
extern int v_detect_abil(struct command *c);
extern int v_dispel_abil(struct command *c);
extern int v_heal(struct command *c);
extern int v_hinder_med(struct command *c);
extern int v_meditate(struct command *c);
extern int v_quick_cast(struct command *c);
extern int v_reveal_mage(struct command *c);
extern int v_save_quick(struct command *c);
extern int v_shroud_abil(struct command *c);
extern int v_tap_health(struct command *c);
extern int v_use_quick_cast(struct command *c);
extern int v_view_aura(struct command *c);
extern int v_write_spell(struct command *c);

/* olympia/beast.c */
extern int d_bird_spy(struct command *c);
extern int d_breed(struct command *c);
extern int d_breed_hound(struct command *c);
extern int v_bird_spy(struct command *c);
extern int v_breed(struct command *c);
extern int v_breed_hound(struct command *c);

/* olympia/build.c */
extern int build_structure(struct command *c, struct build_ent *bi, int new);
extern int d_build(struct command *c);
extern int d_improve(struct command *c);
extern int d_raze(struct command *c);
extern int d_repair(struct command *c);
extern int daily_build(struct command *c, struct build_ent *bi);
extern int fort_default_defense(int sk);
extern int i_repair(struct command *c);
extern int province_subloc(int where, int sk);
extern int start_build(struct command *c, struct build_ent *bi, int new);
extern int v_build(struct command *c);
extern int v_improve(struct command *c);
extern int v_raze(struct command *c);
extern int v_repair(struct command *c);

/* olympia/buy.c */
extern void begin_economy(int where);			/* issue #25: per-market RNG stream */
extern int econ_pick(int item, int where, int low, int high);
extern int econ_stock(int item, int where, int low, int high);
extern int econ_qty(int item, int where, int low, int high);
extern int econ_cost(int item, int where, int low, int high);
extern int econ_expire(int item, int where, int low, int high);
extern int d_find_buy(struct command *c);
extern int d_find_sell(struct command *c);

/* olympia/npc.c */
extern void begin_npc(int where);			/* issue #25: per-location NPC RNG stream */
extern int npc_spawn(int k1, int k2, int low, int high);
extern int npc_qty(int k1, int k2, int low, int high);
extern int npc_behavior(int k1, int k2, int low, int high);
extern int is_tradegood(int item);
extern int new_tradegood(int where);
extern int v_buy(struct command *c);
extern int v_find_buy(struct command *c);
extern int v_find_sell(struct command *c);
extern int v_sell(struct command *c);
extern void check_validated_trades(void);
extern void clear_all_trades(int who);
extern void expire_trades(int where);
extern void investigate_possible_trade(int who, int item, int old_has);
extern void list_pending_trades(int who, int num);
extern void loc_trade_sup(int where, int override);
extern void location_trades(void);
extern void market_report(int who, int where);
extern void match_all_trades(void);
extern void match_trades(int who);
extern void trade_suffuse_ring(int where);

/* olympia/c1.c */
extern int expl_seek(int who, int target);		/* issue #25: per-turn explore RNG stream */
extern int expl_detect(int who, int cand);
extern char *parse_wait_args(struct command *c);
extern int d_add_ram(struct command *c);
extern int d_explore(struct command *c);
extern int d_form(struct command *c);
extern int d_wait(struct command *c);
extern int how_many(int who, int from_who, int item, int qty, int have_left);
extern int i_wait(struct command *c);
extern int next_np_turn(int pl);
extern int v_accept(struct command *c);
extern int v_add_ram(struct command *c);
extern int v_banner(struct command *c);
extern int v_emote(struct command *c);
extern int v_explore(struct command *c);
extern int v_flag(struct command *c);
extern int v_form(struct command *c);
extern int v_fullname(struct command *c);
extern int v_get(struct command *c);
extern int v_give(struct command *c);
extern int v_look(struct command *c);
extern int v_name(struct command *c);
extern int v_pay(struct command *c);
extern int v_split(struct command *c);
extern int v_times(struct command *c);
extern int v_wait(struct command *c);
extern int will_accept(int who, int item, int from, int qty);
extern int will_accept_sup(int who, int item, int from, int qty);
extern void clear_wait_parse(struct command *c);
extern void print_hiring_status(int pl);
extern void print_unformed(int pl);

/* olympia/c2.c */
extern int d_archery(struct command *c);
extern int d_defense(struct command *c);
extern int d_improve_opium(struct command *c);
extern int d_swordplay(struct command *c);
extern int v_archery(struct command *c);
extern int v_board(struct command *c);
extern int v_claim(struct command *c);
extern int v_defense(struct command *c);
extern int v_die(struct command *c);
extern int v_discard(struct command *c);
extern int v_fee(struct command *c);
extern int v_ferry(struct command *c);
extern int v_fight_to_death(struct command *c);
extern int v_format(struct command *c);
extern int v_improve_opium(struct command *c);
extern int v_message(struct command *c);
extern int v_notab(struct command *c);
extern int v_post(struct command *c);
extern int v_press(struct command *c);
extern int v_public(struct command *c);
extern int v_quit(struct command *c);
extern int v_rumor(struct command *c);
extern int v_stop(struct command *c);
extern int v_swordplay(struct command *c);
extern int v_unload(struct command *c);
extern void close_times(void);
extern void drop_player(int pl);
extern void open_times(void);
extern void text_list_free(char **l);
extern void times_masthead(void);

/* olympia/check.c */
extern void check_db(void);

/* olympia/cloud.c */
extern void create_cloudlands(void);

/* olympia/code.c */
extern int letter_val(char c, char *let);
extern void change_box_subkind(int n, int sk);
extern void print_box_usage(void);
extern void print_box_usage_sup(int low, int high, char *s);

/* olympia/combat.c */
extern int cannot_take_booty(int who);
extern int d_pillage(struct command *c);
extern int find_wield(struct wield *w, int who, struct fight *f);
extern int v_attack(struct command *c);
extern int v_behind(struct command *c);
extern int v_execute(struct command *c);
extern int v_guard(struct command *c);
extern int v_pillage(struct command *c);
extern void check_all_auto_attacks(void);
extern void clear_second_waits(void);

/* olympia/day.c */
extern int maint_cost(int item);
extern void add_unformed_sup(int pl);
extern void charge_maint_sup(int who);
extern void daily_events(void);
extern void init_locs_touched(void);
extern void post_month(void);

/* olympia/dir.c */
extern int is_port_city(int where);
extern int los_province_distance(int a, int b);
extern int province_has_port_city(int where);
extern void determine_map_edges(void);

/* olympia/display.c */
extern char *loc_inside_string(int where);
extern int emperor(void);
extern void show_loc(int who, int where);
extern void show_loc_posts(int who, int where, int show_full_loc);

/* olympia/eat.c */
extern void eat_loop(int eat_fast, int mail_now);

/* olympia/faery.c */
extern int v_use_faery_stone(struct command *c);
extern void auto_faery(void);
extern void create_faery(void);
extern void link_opener(int who, int where, int sk);

/* olympia/garr.c */
extern int allowed_garrisons(int level);
extern int count_castle_garrisons(int castle);
extern int garrison_here(int where);
extern int garrison_spot_check(int garr, int target);
extern int garrison_strength(int garr);
extern int new_province_garrison(int where, int castle, int item, int qty);
extern int province_admin(int n);
extern int v_decree(struct command *c);
extern int v_decree_hostile(struct command *c);
extern int v_decree_watch(struct command *c);
extern int v_garrison(struct command *c);
extern int v_pledge(struct command *c);
extern int v_ungarrison(struct command *c);
extern void determine_noble_ranks(void);
extern void garrison_gold(void);
extern void garrison_summary(int pl);
extern void ping_garrisons(void);

/* olympia/gate.c */
extern int d_detect_gates(struct command *c);
extern int d_notify_jump(struct command *c);
extern int d_notify_unseal(struct command *c);
extern int d_rem_seal(struct command *c);
extern int d_reveal_key(struct command *c);
extern int d_seal_gate(struct command *c);
extern int d_unseal_gate(struct command *c);
extern int list_gates_here(int who, int where, int show_dest);
extern int province_gate_here(int where);
extern int v_detect_gates(struct command *c);
extern int v_jump_gate(struct command *c);
extern int v_notify_jump(struct command *c);
extern int v_notify_unseal(struct command *c);
extern int v_rem_seal(struct command *c);
extern int v_reveal_key(struct command *c);
extern int v_reverse_jump(struct command *c);
extern int v_seal_gate(struct command *c);
extern int v_teleport(struct command *c);
extern int v_unseal_gate(struct command *c);

/* olympia/glob.c */
extern void glob_init(void);

/* olympia/gm.c */
extern void gm_list_animate_items(int pl);
extern void gm_report(int pl);
extern void list_all_items(int pl);
extern void list_all_notices(int pl);

/* olympia/hades.c */
extern int random_hades_loc(void);
extern void auto_hades(void);
extern void create_hades(void);

/* olympia/immed.c */
extern int v_add_item(struct command *c);
extern int v_be(struct command *c);
extern int v_credit(struct command *c);
extern int v_ct(struct command *c);
extern int v_dump(struct command *c);
extern int v_fix(struct command *c);
extern int v_fix2(struct command *c);
extern int v_invent(struct command *c);
extern int v_kill(struct command *c);
extern int v_know(struct command *c);
extern int v_listcmds(struct command *c);
extern int v_lore(struct command *c);
extern int v_los(struct command *c);
extern int v_makeloc(struct command *c);
extern int v_plugh(struct command *c);
extern int v_poof(struct command *c);
extern int v_postproc(struct command *c);
extern int v_relore(struct command *c);
extern int v_save(struct command *c);
extern int v_see_all(struct command *c);
extern int v_seed(struct command *c);
extern int v_seedmarket(struct command *c);
extern int v_skills(struct command *c);
extern int v_sub_item(struct command *c);
extern int v_take_pris(struct command *c);
extern int v_xyzzy(struct command *c);
extern void fix_gates(void);
extern void immediate_commands(void);

/* olympia/input.c */
extern int check_allow(struct command *c, char *allow);
extern int find_command(char *s);
extern int finish_command(struct command *c);
extern int min_pri_ready(void);
extern int oly_parse(struct command *c, char *s);
extern int oly_parse_cmd(struct command *c, char *s);
extern int parse_arg(int who, char *s);
extern void check_all_waits(void);
extern void cmd_shift(struct command *c);
extern void command_done(struct command *c);
extern void do_command(struct command *c);
extern void init_load_sup(int who);
extern void init_wait_list(void);
extern void initial_command_load(void);
extern void process_orders(void);
extern void remove_comment(char *s);
extern void remove_ctrl_chars(char *s);
extern void start_phase(void);

/* olympia/io.c */
extern void cleanup_posts(void);
extern void make_dir(char *dir);
extern void olytime_print(FILE *fp, char *header, olytime *p);
extern void olytime_scan(char *s, olytime *p);
extern void save_box(FILE *fp, int n);
extern void save_db(void);
extern void save_logdir(void);
extern void write_player(int pl);

/* olympia/loc.c */
extern int building_owner(int where);
extern int first_character(int where);
extern void all_stack(int who, ilist *l);

/* olympia/lore.c */
extern char *np_req_s(int skill);
extern void deliver_lore(int who, int num);
extern void gm_show_all_skills(int pl);
extern void scan_char_item_lore(void);
extern void scan_char_skill_lore(void);
extern void show_lore_sheets(void);

/* olympia/main.c */
extern void call_init_routines(void);
extern void copy_public_turns(void);
extern void mail_reports(void);
extern void output_html_rep(int pl);
extern int send_rep(int pl, int turn);
extern int v_remail(struct command *c);
extern void write_faction_sup(int who_for, int target, FILE *fp);
extern void write_forward_sup(int who_for, int target, FILE *fp);
extern void extract_startlocs(void);
extern void set_html_pass(int pl);
extern void setup_html_dir(int pl);
extern void write_email(void);
extern void write_factions(void);
extern void write_forwards(void);
extern void write_player_list(void);
extern void write_totimes(void);

/* olympia/make.c */
extern int d_generic_make(struct command *c, struct make *t);
extern int d_make(struct command *c);
extern int d_second_make(struct command *c, struct make *t);
extern int i_generic_make(struct command *c, struct make *t);
extern int i_make(struct command *c);
extern int v_generic_make(struct command *c, int number, struct make *t);
extern int v_make(struct command *c);
extern int v_second_make(struct command *c, int number, struct make *t);
extern int v_use_train_riding(struct command *c);
extern int v_use_train_war(struct command *c);

/* olympia/move.c */
extern int d_fly(struct command *c);
extern int d_move(struct command *c);
extern int d_sail(struct command *c);
extern int i_sail(struct command *c);
extern int v_east(struct command *c);
extern int v_enter(struct command *c);
extern int v_exit(struct command *c);
extern int v_fly(struct command *c);
extern int v_move(struct command *c);
extern int v_north(struct command *c);
extern int v_sail(struct command *c);
extern int v_south(struct command *c);
extern int v_west(struct command *c);
extern void check_captain_loses_sailors(int qty, int target, int inform);
extern void check_ocean_chars(void);
extern void clear_guard_flag(int who);
extern void departure_message(int who, struct exit_view *v);
extern void init_ocean_chars(void);
extern void move_stack(int who, int where);
extern void restore_stack_actions(int who);
extern void touch_loc_after_move(int who, int where);

/* olympia/necro.c */
extern int d_aura_blast(struct command *c);
extern int d_banish_undead(struct command *c);
extern int d_eat_dead(struct command *c);
extern int d_keep_undead(struct command *c);
extern int d_undead_lord(struct command *c);
extern int v_aura_blast(struct command *c);
extern int v_aura_reflect(struct command *c);
extern int v_banish_undead(struct command *c);
extern int v_eat_dead(struct command *c);
extern int v_keep_undead(struct command *c);
extern int v_undead_lord(struct command *c);
extern void auto_undead(int who);

/* olympia/npc.c */
extern int controlled_humans_here(int where);
extern int create_peasant_mob(int where, struct rng_stream *rng);
extern struct exit_view *choose_npc_direction(int who, int where, int dir);
extern struct exit_view *get_exit_dir(exit_views_list l, int dir);
extern void faery_attack_check(int who, int where);
extern void hades_attack_check(int who, int where);
extern void npc_move(int who);
extern void queue_npc_orders(void);

/* olympia/order.c */
extern void queue(int who, char *s, ...)
    __attribute__((format(printf, 2, 3)));
extern void flush_unit_orders(int pl, int who);
extern void list_order_templates(void);
extern void load_orders(void);
extern void orders_template(int who, int pl);
extern void save_orders(void);
extern void save_player_orders(int pl);

/* olympia/perm.c */
extern int is_defend(int who, int targ);
extern int is_hostile(int who, int targ);
extern int v_admit(struct command *c);
extern int v_att_clear(struct command *c);
extern int v_defend(struct command *c);
extern int v_hostile(struct command *c);
extern int v_neutral(struct command *c);
extern int will_admit(int pl, int who, int targ);
extern void clear_all_att(int who);
extern void print_admit(int pl);
extern void print_att(int who, int n);
extern void set_att(int who, int targ, int disp);

/* olympia/produce.c */
extern int d_collect(struct command *c);
extern int d_generic_harvest(struct command *c, struct harvest *t);
extern int d_mine_gold(struct command *c);
extern int d_mine_iron(struct command *c);
extern int d_mine_mithril(struct command *c);
extern int finish_generic_mine(struct command *c, int item);
extern int i_collect(struct command *c);
extern int i_generic_harvest(struct command *c, struct harvest *t);
extern int start_generic_mine(struct command *c, int item);
extern int v_catch(struct command *c);
extern int v_collect(struct command *c);
extern int v_fish(struct command *c);
extern int v_generic_harvest(struct command *c, int number, int days, struct harvest *t);
extern int v_mage_menial(struct command *c);
extern int v_mallorn(struct command *c);
extern int v_mine_gold(struct command *c);
extern int v_mine_iron(struct command *c);
extern int v_mine_mithril(struct command *c);
extern int v_opium(struct command *c);
extern int v_quarry(struct command *c);
extern int v_raise_corpses(struct command *c);
extern int v_recruit(struct command *c);
extern int v_wood(struct command *c);
extern int v_yew(struct command *c);
extern void init_collect_list(void);
extern void location_production(void);
extern void mine_production(int where);

/* olympia/pw.c */
extern char *read_pw(char *type);

/* olympia/quest.c */
extern void begin_quest(int key);			/* issue #25: per-quest RNG stream */
extern int qrnd(int low, int high);
extern int choose_quest_monster(int where);
extern int d_quest(struct command *c);
extern int make_subloc_monster(int where, int questor);
extern int random_unassigned_relic(void);
extern int v_quest(struct command *c);
extern int v_use_bta_skull(struct command *c);
extern void create_nowhere(void);
extern void create_relics(void);

/* olympia/relig.c */
extern int d_last_rites(struct command *c);
extern int d_prep_ritual(struct command *c);
extern int d_remove_bless(struct command *c);
extern int d_resurrect(struct command *c);
extern int d_reveal_vision(struct command *c);
extern int d_vision_protect(struct command *c);
extern int v_last_rites(struct command *c);
extern int v_prep_ritual(struct command *c);
extern int v_remove_bless(struct command *c);
extern int v_resurrect(struct command *c);
extern int v_reveal_vision(struct command *c);
extern int v_vision_protect(struct command *c);

/* olympia/report.c */
extern int stupid_word(char *s);
extern void char_rep_sup(int who, int num);
extern void character_report(void);
extern void charge_account(void);
extern void determine_output_order(void);
extern void gen_include_section(void);
extern void gen_include_sup(int pl);
extern void loc_stack_report(int pl);
extern void player_banner(void);
extern void player_ent_info(void);
extern void player_report(void);
extern void player_report_sup(int pl);
extern void report_account(void);
extern void report_account_sup(int pl);
extern void show_carry_capacity(int who, int num);
extern void show_item_skills(int who, int num);
extern void show_unclaimed(int who, int num);
extern void sort_for_output(ilist l);
extern void stack_capacity_report(int pl);
extern void turn_end_loc_reports(void);
extern void unit_summary(int pl);

/* olympia/savage.c */
extern int d_keep_savage(struct command *c);
extern int v_keep_savage(struct command *c);
extern int v_summon_savage(struct command *c);
extern int v_use_drum(struct command *c);
extern void auto_savage(int who);
extern void init_savage_attacks(void);

/* olympia/scry.c */
extern int cast_check_char_here(int who, int target);
extern int cast_where(int who);
extern int d_bar_loc(struct command *c);
extern int d_detect_scry(struct command *c);
extern int d_dispel_region(struct command *c);
extern int d_locate_char(struct command *c);
extern int d_proj_cast(struct command *c);
extern int d_save_proj(struct command *c);
extern int d_scry_region(struct command *c);
extern int d_shroud_region(struct command *c);
extern int d_unbar_loc(struct command *c);
extern int reset_cast_where(int who);
extern int v_bar_loc(struct command *c);
extern int v_detect_scry(struct command *c);
extern int v_dispel_region(struct command *c);
extern int v_locate_char(struct command *c);
extern int v_proj_cast(struct command *c);
extern int v_save_proj(struct command *c);
extern int v_scry_region(struct command *c);
extern int v_shroud_region(struct command *c);
extern int v_unbar_loc(struct command *c);
extern int v_use_proj_cast(struct command *c);
extern void alert_palantir_scry(int who, int where);
extern void alert_scry_generic(int who, int where);
extern void notify_loc_shroud(int where);
extern void scry_show_where(int who, int target);
extern void show_item_where(int who, int target);

/* olympia/seed.c */
extern void compute_dist(void);
extern void compute_dist_gate(void);
extern void prop_city_near_list(int city);
extern void seed_city(int where);
extern void seed_city_near_lists(void);
extern void seed_city_trade(int where);
extern void seed_cookies(void);
extern void seed_initial_locations(void);
extern void seed_mob_cookies(void);
extern void seed_phase_two(void);
extern void seed_taxes(void);
extern void seed_undead_cookies(void);
extern void seed_weather_cookies(void);

/* olympia/sout.c */
extern ilist save_output_vector(void);
extern void init_spaces(void);
extern void close_logfile(void);
extern void initialize_buffer(void);
extern void open_logfile(void);
extern void open_logfile_nondestruct(void);
extern void vector_clear(void);
extern void vector_players(void);
extern void vout(int who, const char *format, va_list vargs);

/* olympia/stack.c */
extern int here_pos(int who);
extern int here_precedes(int a, int b);
extern int v_promote(struct command *c);
extern int v_stack(struct command *c);
extern int v_surrender(struct command *c);
extern int v_unstack(struct command *c);
extern void extract_stacked_unit(int who);
extern void free_all_prisoners(int who);
extern void prisoner_movement_escape_check(int who);
extern void weekly_prisoner_escape_check(void);

/* olympia/stealth.c */
extern int cloak_lord(int n);
extern int d_find_rich(struct command *c);
extern int d_hide(struct command *c);
extern int d_petty_thief(struct command *c);
extern int d_seek(struct command *c);
extern int d_sneak(struct command *c);
extern int d_spy_inv(struct command *c);
extern int d_spy_lord(struct command *c);
extern int d_spy_skills(struct command *c);
extern int d_torture(struct command *c);
extern int v_contact(struct command *c);
extern int v_find_rich(struct command *c);
extern int v_hide(struct command *c);
extern int v_petty_thief(struct command *c);
extern int v_seek(struct command *c);
extern int v_sneak(struct command *c);
extern int v_spy_inv(struct command *c);
extern int v_spy_lord(struct command *c);
extern int v_spy_skills(struct command *c);
extern int v_torture(struct command *c);
extern void clear_contacts(int stack);

/* olympia/storm.c */
extern void begin_weather(void);			/* issue #25: per-turn weather RNG stream */
extern void wthr_shuffle(ilist l);
extern int wthr_storm(int where, int k2, int low, int high);
extern int wthr_wreck(int where, int sub, int low, int high);
extern int d_banish_corpses(struct command *c);
extern int d_bind_storm(struct command *c);
extern int d_death_fog(struct command *c);
extern int d_dissipate(struct command *c);
extern int d_fierce_wind(struct command *c);
extern int d_lightning(struct command *c);
extern int d_renew_storm(struct command *c);
extern int d_seize_storm(struct command *c);
extern int d_summon_fog(struct command *c);
extern int d_summon_rain(struct command *c);
extern int d_summon_wind(struct command *c);
extern int v_banish_corpses(struct command *c);
extern int v_bind_storm(struct command *c);
extern int v_death_fog(struct command *c);
extern int v_direct_storm(struct command *c);
extern int v_dissipate(struct command *c);
extern int v_fierce_wind(struct command *c);
extern int v_lightning(struct command *c);
extern int v_renew_storm(struct command *c);
extern int v_seize_storm(struct command *c);
extern int v_summon_fog(struct command *c);
extern int v_summon_rain(struct command *c);
extern int v_summon_wind(struct command *c);
extern void dissipate_storm(int storm, int show);
extern void init_weather_views(void);
extern void move_bound_storms(int ship, int where);
extern void natural_weather(void);
extern void storm_report(int pl);
extern void update_weather_view_locs(int stack, int where);

/* olympia/summary.c */
extern void summary_report(void);

/* olympia/swear.c */
extern int d_bribe(struct command *c);
extern int d_incite(struct command *c);
extern int d_persuade_oath(struct command *c);
extern int d_raise(struct command *c);
extern int d_rally(struct command *c);
extern int d_terrorize(struct command *c);
extern int enough_np_to_acquire(int who, int target);
extern int np_to_acquire(int who, int target);
extern int sworn_beneath(int a, int b);
extern int terrorize_prisoner(struct command *c);
extern int terrorize_vassal(struct command *c);
extern int v_bribe(struct command *c);
extern int v_honor(struct command *c);
extern int v_incite(struct command *c);
extern int v_oath(struct command *c);
extern int v_persuade_oath(struct command *c);
extern int v_raise(struct command *c);
extern int v_rally(struct command *c);
extern int v_swear(struct command *c);
extern int v_terrorize(struct command *c);

/* olympia/tunnel.c */
extern int create_tunnel_set(int city, int subworld_link);
extern int random_subworld_loc(void);
extern void create_tunnels(void);
extern void fill_dir_exits(int where);

/* olympia/u.c */
extern int autocharge(int who, int amount);
extern int char_here(int who, int target);
extern int char_where(int where, int who, int target);
extern int check_char_where(int where, int who, int target);
extern int check_skill(int who, int skill);
extern int contacted(int a, int b);
extern int count_any(int who);
extern int count_fighters(int who);
extern int count_stack_any(int who);
extern int count_stack_fighters(int who);
extern int count_stack_move_nobles(int who);
extern int create_unique_item_alloc(int new, int who, int sk);
extern int loc_depth(int n);
extern int max(int a, int b);
extern int min(int a, int b);
extern int nprovinces(void);
extern int ship_cap(int ship);
extern int stack_sub_item(int who, int item, int qty);
extern int survive_fatal(int who);
extern int test_bit(sparse kr, int i);
extern int v_reclaim(struct command *c);
extern void bark_dogs(int where);
extern void char_reclaim(int who);
extern void get_rid_of_collapsed_mine(int fort);
extern void print_dot(int c);
extern void put_back_cookie(int who);
extern void restore_dead_body(int owner, int who);

/* olympia/use.c */
/* issue #25 (step 9): per-turn skills RNG stream; helpers called from c2.c/stealth.c */
extern int skil_crit(int who, int wsk);
extern int skil_bonus(int who, int wsk, int low, int high);
extern int skil_torture(int who, int target);
extern int skil_petty(int who, int where, int sub, int low, int high);
extern int char_np_total(int who);
extern int d_research(struct command *c);
extern int d_study(struct command *c);
extern int d_use(struct command *c);
extern int d_use_item(struct command *c);
extern int i_use(struct command *c);
extern int skill_cost(int sk);
extern int v_forget(struct command *c);
extern int v_research(struct command *c);
extern int v_study(struct command *c);
extern int v_use(struct command *c);
extern int v_use_item(struct command *c);
extern void add_skill_experience(int who, int sk);
extern void experience_use_speedup(struct command *c);
extern void list_partial_skills(int who, int num);
extern void list_skill_sup(int who, struct skill_ent *e);

#endif
