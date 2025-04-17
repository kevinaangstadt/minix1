/* const apparently doens't exist */
#define const

/* this appears to be needed by bcc */
void *memcpy(dest, src, n)
void *dest;
const void *src;
long n;
{
  char *d = dest;
  const char *s = src;

  while (n--) {
    *d++ = *s++;
  }
  return dest;
}