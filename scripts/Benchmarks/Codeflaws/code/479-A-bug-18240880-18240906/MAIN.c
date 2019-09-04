extern int INPUT1;
extern int INPUT2;
extern int INPUT3;
extern int BUGGY_RES1;
extern int CORRECT_RES1;

extern int AllRepair_buggy_main(int argc, char *argv[]);
extern int AllRepair_correct_main(int argc, char *argv[]);

#include <assert.h>
#include <string.h>

int main(int argc, char *argv[])
{
  INPUT1 = nondet();
  INPUT2 = nondet();
  INPUT3 = nondet();
  AllRepair_buggy_main(argc, argv);
  AllRepair_correct_main(argc, argv);
  assert(BUGGY_RES1==CORRECT_RES1);
}
