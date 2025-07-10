#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>

int main(int argc, char const *argv[]) {
    openlog(NULL, 0, LOG_USER);
    
    if (argc <= 2) {
        syslog(LOG_ERR, "Invalid number of arguments");
        return 1;
    }

    const char* writefile = argv[1];
    const char* writestr  = argv[2];
    syslog(LOG_DEBUG, "Writing %s to %s\n", writestr, writefile);

    FILE* f = fopen(writefile, "w");

    if (f == NULL) {
        openlog(NULL, 0, LOG_USER);
        syslog(LOG_ERR, "Error opening write file");
        return 1;
    }
    else {
        fprintf(f, "%s\n", writestr);
        fclose(f);
    }

    return 0;
}
