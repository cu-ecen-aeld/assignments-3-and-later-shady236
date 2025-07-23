#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <syslog.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <stdbool.h>
#include <stdio.h>
#include <poll.h>
#include <signal.h>


bool stop = false;
void handle_signals(int sig) {
    syslog(0, "Caught signal, exiting\n");
    stop = true;
}


void ipToStr(struct sockaddr* addr, char* buf, int sz) {
    if (addr->sa_family == AF_INET) {
        struct sockaddr_in *addr4 = (struct sockaddr_in *)addr;
        inet_ntop(AF_INET, &(addr4->sin_addr), buf, sz);
    } else if (addr->sa_family == AF_INET6) {
        struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)addr;
        inet_ntop(AF_INET6, &(addr6->sin6_addr), buf, sz);
    }
}


bool isAnyWaiting(int serverSockFd) {
    struct pollfd pfd;
    pfd.fd = serverSockFd;
    pfd.events = POLLIN;
    
    int ready = poll(&pfd, 1, 1000); // 1000ms timeout
    return (ready > 0 && (pfd.revents & POLLIN));
}


#define   BUF_SIZE     (1024)

int main(int argc, char** argv) {
    int serverSockFd = -1;
    struct addrinfo *serverAddr;
    char ipAsStr[INET6_ADDRSTRLEN];
    struct addrinfo hints;
    char buf[BUF_SIZE];
    int rc;
    int clientSockFd;    
    struct sockaddr clientAddr;
    socklen_t clientAddrLen = sizeof(clientAddr);

    signal(SIGINT, handle_signals);
    signal(SIGTERM, handle_signals);
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    if (getaddrinfo(NULL, "9000", &hints, &serverAddr) != 0) {
        return -1;
    }

    for (struct addrinfo *p = serverAddr; p != NULL; p = p->ai_next) {
        serverSockFd = socket(p->ai_family, p->ai_socktype, p->ai_protocol);
        if (serverSockFd == -1) {
            continue;
        }
	ipToStr(p->ai_addr, ipAsStr, INET6_ADDRSTRLEN);
        if (bind(serverSockFd, p->ai_addr, p->ai_addrlen) == 0) {
	    break;
	}
	close(serverSockFd);
	serverSockFd = -1;
    }

    freeaddrinfo(serverAddr);
    if (serverSockFd == -1) {
        return -1;
    }

    if (listen(serverSockFd, 1) != 0) {
        return -1;
    }

    if (argc >= 2 && strcmp(argv[1], "-d") == 0) {
        pid_t id = fork();
	if (id < 0) {
	    return -1;
	} else if (id > 0) {
	    return 0;
	}
    } 
    
    int rxFd = open("/var/tmp/aesdsocketdata", O_CREAT | O_TRUNC | O_RDWR, 0644);
    if (rxFd < 0) {
        return -1;
    }

    while (!stop) {
	if (!isAnyWaiting(serverSockFd)) {
	    continue;
	}

	clientSockFd = accept(serverSockFd, &clientAddr, &clientAddrLen);
	if (clientSockFd < 0) {
	    return -1;
	}

	ipToStr(&clientAddr, ipAsStr, INET6_ADDRSTRLEN);
	syslog(0, "Accepted connection from %s\n", ipAsStr);

	while (1) {
	    do {
                rc = recv(clientSockFd, buf, BUF_SIZE, 0);
		write(rxFd, buf, rc);
	    } while (rc > 0 && buf[rc - 1] != '\n');
	    if (rc <= 0) {
	        break;
	    }

	    lseek(rxFd, 0, SEEK_SET);
	    do {
	        rc = read(rxFd, buf, BUF_SIZE);
		send(clientSockFd, buf, rc, 0);
	    } while (rc > 0);
	}
	
	syslog(0, "Closed connection from %s\n", ipAsStr);
	close(clientSockFd);
    }
    
    close(rxFd);
    close(serverSockFd);
    remove("/var/tmp/aesdsocketdata");
    return 0;
}
