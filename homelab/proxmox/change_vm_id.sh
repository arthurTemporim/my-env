export vgNAME=vg-images newVMID=173 oldVMID=175 ;  \
for i in $(lvs -a|grep $vgNAME | awk '{print $1}' | grep $oldVMID); \
do lvrename $vgNAME/vm-$oldVMID-disk-$(echo $i | awk '{print substr($0,length,1)}') vm-$newVMID-disk-$(echo $i | awk '{print substr($0,length,1)}'); done; \
sed -i "s/$oldVMID/$newVMID/g" /etc/pve/qemu-server/$oldVMID.conf; mv /etc/pve/qemu-server/$oldVMID.conf /etc/pve/qemu-server/$newVMID.conf; \
unset vgNAME newVMID oldVMID;
