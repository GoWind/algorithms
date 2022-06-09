#include<stdio.h>
#include<stdlib.h>

enum
{
	Match = 256,
	Split = 257
};

typedef struct State State;
struct State
{
	int c;
	State *out;
	State *out1;
	int lastlist;
};
State matchstate = { Match };	/* matching state */
State matchstate2 = { Match };	/* matching state */

typedef struct Frag Frag;
typedef union Ptrlist Ptrlist;
typedef struct Frag {
  State *start;
  Ptrlist *out;
};

union Ptrlist
{
	Ptrlist *next;
	State *s;
};

Frag
frag(State *start, Ptrlist *out)
{
	Frag n = { start, out };
	return n;
}

Ptrlist*
list1(State **outp)
{
	Ptrlist *l;
	
	l = (Ptrlist*)outp;
	l->next = NULL;
	return l;
}

int main() {
  matchstate.out = &matchstate2;
  Ptrlist *l = list1(&matchstate.out);
  printf("%d\n", matchstate.c);
  printf("%d\n", matchstate.lastlist);
  printf("%p\n", matchstate.out);
  printf("%p\n", &matchstate2);
  printf("%u\n", l->next);
  printf("%u\n", l->s);
  return 0;
}


