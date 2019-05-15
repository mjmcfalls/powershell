## Code related to OS deployment and images.


* installVirtIoDrivers.ps1
  * Used to inject VirtIO Drivers from the Fedora VirtIO project (https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/) into a Windows WIM; used on the "virtio-win iso" download, which was extracted by 7zip. 
  * Used primary on Windows Server 2019 Evaluation version WIM for deployment on Nutanix CE.  
