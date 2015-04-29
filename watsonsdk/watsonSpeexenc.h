#include <stdio.h>

//extern "C" {
#import "speexenc.h"
//}


int pcmEnc(const char *filepathPCM,const char *filepathSPX, _Bool hasHeader, int serialno, long *pageSeq);
void headerToFile(FILE *fout_tmp, int serialno, long *pageSeq);
extern int oe_write_page(ogg_page *page, FILE *fp);
