# subvert realm command and install fake version of realmd. the real one brings in polkit which breaks systemd
rpm -Uvh /testcase/spec/mock/realmd*.rpm
yum install -y sssd oddjob
cp /testcase/spec/mock/realm /usr/sbin/realm

# sssd won't start with an sssd.conf file present (real startup) because conterised so needs a fake unit file that
# does nothing
cp /testcase/spec/mock/sssd.service /usr/lib/systemd/system/sssd.service
cp /testcase/spec/mock/oddjobd.service /usr/lib/systemd/system/oddjobd.service

systemctl daemon-reload