#include<stdio.h>
#include<stdlib.h>
#include<assert.h>


struct dictnode {
  int prefix;
  unsigned char val;
  int value;
  struct dictnode* next;
};
typedef struct dictnode dictnode;

dictnode* init_dict() {
  dictnode* d  = malloc(sizeof(dictnode));
  d->prefix = 0;
  d->val = 0;
  d->next = NULL;
  return d;
}

unsigned char printstr(dictnode*, int);
int find_str(dictnode* s, int prefix, char val) {
  if (s == NULL) return -1;
  dictnode* k  = s;
  while(k != NULL) {
    if (k->prefix == prefix && k->val == val)
        return k->value;
    else 
        k = k->next;
  }
  return -1;
}

int find_prefix_char(dictnode* d, int val, int*  prefix, unsigned char* code) {
    if(d == NULL) return -1;
    dictnode* k = d;
    while(k != NULL)
      if (k->value == val) {
            *prefix = k->prefix;
            *code = k->val;
            return 1;
      } else {
        k = k->next;
     }
    return -1;
} 
    

int add_str(dictnode* s, int prefix, unsigned char val, int value) {
  if (s == NULL)
        return 0;
  dictnode* k = s;
  while(k->next != NULL) k = k->next;
  k->next = malloc(sizeof(dictnode));
  (k->next)->prefix = prefix;
  (k->next)->val = val;
  (k->next)->value = value;
  (k->next)->next = NULL;
  return 1;
}
 

dictnode*  init_codes() {
  dictnode* d = init_dict();
  assert(d!= NULL);
  for (int i = 0 ; i < 256; i++) {
    add_str(d, -1, (unsigned char)i, (int)i);
  }
  return d;
}

void lzwcompress(unsigned char* stream, int len, int* op, int* count) {
    dictnode* k = init_codes();
    int items = 0;
    int prefix = -1;
    int idx = 0;
    int cur = 256;
    unsigned char cur_value;
    while(idx < len ) {
        cur_value = stream[idx];
        int v = find_str(k, prefix, cur_value);
        if (v == -1) { // add to dictionary
          add_str(k, prefix, cur_value, cur);
          op[(*count)++] = prefix;
          cur++;
          prefix = find_str(k, -1, cur_value);
        } else {
          prefix = v;
        }
        idx++;
    }
    op[(*count)++] = prefix;
}

void decompress(int* values, int len) {
  dictnode* d = init_codes();
  if (len == 0) return;
  int j = 0;
  int ocode  = values[j];
  int v = find_str(d, -1,ocode);
  int ncode;
  int prefix = -1;
  int nextval = 256;
  unsigned char cchar  = 0;
  unsigned char cx = 0;
  printf("%c", ocode);
  j++;
  while( j < len) {
      ncode = values[j];
      int m = find_prefix_char(d, ncode, &prefix, &cx);
      if (m != -1) {
          cchar = printstr(d, ncode);
      } else {
        cchar = printstr(d, ocode);
        printf("%c", cchar);
      }
      add_str(d, ocode, cchar, nextval);
      nextval++;
      ocode = ncode;
      j++;
  }
}       
        
     

unsigned char printstr(dictnode* d, int code) {
      // print the string for code returning the first character for the string
      // print the str associated with code
      if (code <=255) {
          printf("%c", code);
          return (unsigned char) code;
      } else {
      // find the prefix for the code. recursive find the prefix for the prefix 
     //  until we find the first char (with prefix = 1) and the finally print the char
     // associated with the code
        int prefix;
        unsigned char c;
        find_prefix_char(d, code, &prefix, &c);
        if(prefix != -1) { printstr(d, prefix); }
        printf("%c",c);
        return c;
      } 
 }

int main(void) {
  int k[40];
  int c=0;
  lzwcompress("BAwitdaba",9, k, &c); 
  printf("%d\n",c);
  for(int i=0;i<c;i++) { printf("%d\n", k[i]); }
  printf("\n%s","BAwitdaba\n");
  decompress(k,c);
  return 0;
} 
