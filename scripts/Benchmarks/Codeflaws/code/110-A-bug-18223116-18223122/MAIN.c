char INPUT1[100];
int BUGGY_RES1;
int CORRECT_RES1;

extern int AllRepair_buggy_main(int argc, char *argv[]);
extern int AllRepair_correct_main(int argc, char *argv[]);

#include <assert.h>
#include <string.h>

int main(int argc, char *argv[])
{
  strcpy(INPUT1,nondet());
  AllRepair_buggy_main(argc, argv);
  AllRepair_correct_main(argc, argv);
  assert(BUGGY_RES1==CORRECT_RES1);
}
