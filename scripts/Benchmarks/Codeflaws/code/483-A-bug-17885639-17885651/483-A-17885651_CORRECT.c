extern long long int INPUT1;
extern long long int INPUT2;
extern long long int CORRECT_RES1;
extern long long int CORRECT_RES2;
extern long long int CORRECT_RES3;

#include <stdio.h>
int AllRepair_correct_main(int argc, char *argv[])
{
    long long int l, r, i;
    //scanf("%lld %lld", &l, &r);
    l = INPUT1;
    r = INPUT2;
    if(r-l<=1)
        //printf("-1\n");
	{CORRECT_RES1=-1; CORRECT_RES2=-1; CORRECT_RES3=-1;}
    else if(r-l==2)
    {
        if(l%2==1)
            //printf("-1\n");
	    {CORRECT_RES1=-1; CORRECT_RES2=-1; CORRECT_RES3=-1;}
        else 
            //printf("%lld %lld %lld\n", l, l+1, r);
	    {CORRECT_RES1=l; CORRECT_RES2=l+1; CORRECT_RES3=r;}
    }
    else
    {
        if(l%2==1)
            //printf("%lld %lld %lld\n", l+1, l+2, l+3);
	    {CORRECT_RES1=l+1; CORRECT_RES2=l+2; CORRECT_RES3=l+3;}
        else
            //printf("%lld %lld %lld\n", l, l+1, l+2);
	    {CORRECT_RES1=l; CORRECT_RES2=l+1; CORRECT_RES3=l+2;}
    }
    return 0;
}
