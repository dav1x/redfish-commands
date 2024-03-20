FROM registry.access.redhat.com/ubi8:latest 

<<<<<<< HEAD
#RUN curl -o /tmp/bootstrap.cgi https://linux.dell.com/repo/hardware/dsu/bootstrap.cgi \
# && sed -i 's/IMPORT_GPG_CONFIRMATION="na"/IMPORT_GPG_CONFIRMATION="yes"/' /tmp/bootstrap.cgi \
# && bash /tmp/bootstrap.cgi

RUN dnf -y update \
 && dnf -y install openssl openssl-devel pciutils wget curl \
# && dnf search racadm \
# && dnf install -y srvadmin-idracadm7.x86_64 \
=======
RUN curl -o /tmp/bootstrap.cgi https://linux.dell.com/repo/hardware/dsu/bootstrap.cgi \
 && sed -i 's/IMPORT_GPG_CONFIRMATION="na"/IMPORT_GPG_CONFIRMATION="yes"/' /tmp/bootstrap.cgi \
 && bash /tmp/bootstrap.cgi

RUN dnf -y update \
 && dnf -y install openssl openssl-devel pciutils wget curl \
 && dnf search racadm \
 && dnf install -y srvadmin-idracadm7.x86_64 \
>>>>>>> faeeda2 (first commit)
 && dnf -y clean all

COPY smc/smcBootFromCDFull.sh /smcBootFromCDFull.sh
COPY zt/ztBootFromCDFull.sh /ztBootFromCDFull.sh

# TODO merge the dell idracboot
<<<<<<< HEAD
# COPY dell/delliDracCD.sh /delliDracCD.sh
=======
COPY dell/delliDracCD.sh /delliDracCD.sh
>>>>>>> faeeda2 (first commit)

COPY /boot-from-iso.sh /boot-from-iso.sh

#CMD ["/bin/sh"]
ENTRYPOINT ["/boot-from-iso.sh"]
