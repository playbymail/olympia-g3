
extern int here_preceeds(int a, int b);
extern int stack_parent(int who);
extern int stack_leader(int who);
extern int stacked_beneath(int a, int b);
extern void leave_stack(int who);
extern void join_stack(int who, int stack);
extern void drop_stack(int who, int to_drop);
extern void promote_stack(int lower, int higher);
extern void take_prisoner(int who, int target);
extern int has_prisoner(int who, int pris);
extern int give_prisoner(int who, int target, int pris);
extern int move_prisoner(int who, int target, int pris);
extern void promote(int who, int new_pos);
#define	ESC_WEEKLY	0	/* check_prisoner_escape sub: weekly check */
#define	ESC_MOVE	1	/* captor move, at most one a day */
#define	ESC_GIVE	2	/* ESC_GIVE + n: the prisoner's nth give today */

extern int check_prisoner_escape(int who, int chance, int sub);
extern void prisoner_escapes(int who);
