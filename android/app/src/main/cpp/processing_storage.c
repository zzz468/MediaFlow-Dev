// MediaFlow-owned filesystem bridge. No FFmpeg or third-party media code.
#include <jni.h>
#include <errno.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <fcntl.h>

JNIEXPORT jint JNICALL
Java_com_mediaflow_mediaflow_processing_AtomicOutputStore_renameNoReplace(
    JNIEnv *env, jclass type, jbyteArray source, jbyteArray target) {
    (void)type;
    jbyte *from=(*env)->GetByteArrayElements(env,source,NULL);
    if(!from)return ENOMEM;
    jbyte *to=(*env)->GetByteArrayElements(env,target,NULL);
    if(!to){(*env)->ReleaseByteArrayElements(env,source,from,JNI_ABORT);return ENOMEM;}
    int code;
#ifdef __NR_renameat2
    // RENAME_NOREPLACE=1. Never fall back to an overwriting rename.
    code=syscall(__NR_renameat2,AT_FDCWD,(const char *)from,AT_FDCWD,(const char *)to,1)==0?0:errno;
#else
    code=ENOSYS;
#endif
    (*env)->ReleaseByteArrayElements(env,target,to,JNI_ABORT);
    (*env)->ReleaseByteArrayElements(env,source,from,JNI_ABORT);
    return code;
}
