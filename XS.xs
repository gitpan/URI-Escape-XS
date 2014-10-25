/*
 * $Id: XS.xs,v 0.3 2009/01/16 06:38:52 dankogai Exp dankogai $
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* #include "ppport.h" */
/* #include <URI::Escape::XS> */

# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <ctype.h>

static char escapes[256] = 
/*  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f */
{
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
};

SV *encode_uri_component(SV *str){
    int slen   = SvCUR(str);
    int dlen   = 0;
    SV *result = newSV(slen * 3 + 1); /* at most 3 times */
    U8 *src, *dst;
    int i;

    SvPOK_on(result);
    src   = (U8 *)SvPV_nolen(str);
    dst   = (U8 *)SvPV_nolen(result);

    for (i = 0; i < slen; i++){
	if (escapes[ src[i] ]){
	    sprintf((char *)(dst + dlen), "%%%02X", src[i]);
	    dlen += 3;
	}
	else{
	    dst[dlen++] = src[i];
	}
    }
    dst[dlen] = '\0'; /*  for sure; */
    SvCUR_set(result, dlen);
    return result;
}

SV *decode_uri_component(SV *uri){
    int slen = SvCUR(uri);
    int dlen = 0;
    SV *result = newSV(slen + 1);
    U8 buf[8], *dst, *src, *bp;
    int i, hi, lo;
   
    SvPOK_on(result);
    dst  = (U8 *)SvPV_nolen(result);
    src  = (U8 *)SvPV_nolen(uri);

    for (i = 0; i < slen; i++){
	if (src[i] == '%'){
	    if (isxdigit(src[i+1]) && isxdigit(src[i+2])){
		strncpy((char *)buf, (char *)(src + i + 1), 2);
		hi = strtol((char *)buf, NULL, 16);
		dst[dlen++] = hi;
		i += 2;
	    }
	    else if(src[i+1] == 'u'
		    && isxdigit(src[i+2]) && isxdigit(src[i+3])
		    && isxdigit(src[i+4]) && isxdigit(src[i+5])){
		strncpy((char *)buf, (char *)(src + i + 2), 4);
		buf[4] = '\0'; /* RT#39135 */
		hi = strtol((char *)buf, NULL, 16);
		i += 5;
		if (hi < 0xD800  || 0xDFFF < hi){
		    bp = uvchr_to_utf8((U8 *)buf, (UV)hi);
		    strncpy((char *)(dst+dlen), (char *)buf, bp - buf);
		    dlen += bp - buf;
		}else{
		    if (0xDC00 <= hi){ /* invalid */
			warn("U+%04X is an invalid surrogate hi\n", hi);
		    }else{
			i++;
			if(src[i] == '%' && src[i+1] == 'u'
			   && isxdigit(src[i+2]) && isxdigit(src[i+3])
			   && isxdigit(src[i+4]) && isxdigit(src[i+5])){
			    strncpy((char *)buf, (char *)(src + i + 2), 4);
			    lo = strtol((char *)buf, NULL, 16);
			    i += 5;
			    if (lo < 0xDC00 || 0xDFFF < lo){
				warn("U+%04X is an invalid lo surrogate", lo);
			    }else{
				lo += 0x10000
				    + (hi - 0xD800) * 0x400 -  0xDC00;
				bp = uvchr_to_utf8((U8 *)buf, (UV)lo);
				strncpy((char *)(dst+dlen), (char *)buf, bp - buf);
				dlen += bp - buf;
			    }
			}else{
			    warn("lo surrogate is missing for U+%04X", hi);
			}
		    }
		}
	    }else{
		dst[dlen++] = '%';
	    }
	}
	else{
	    dst[dlen++] = src[i];
	}
    }
    dst[dlen] = '\0'; /*  for sure; */
    SvCUR_set(result, dlen);
    return result;
}

MODULE = URI::Escape::XS		PACKAGE = URI::Escape::XS
PROTOTYPES: ENABLE

SV *
encodeURIComponent(str)
    SV *str;
CODE:
    RETVAL = encode_uri_component(str);
OUTPUT:
    RETVAL

SV *
decodeURIComponent(str)
    SV *str;
CODE:
    RETVAL = decode_uri_component(str);
OUTPUT:
    RETVAL
