# DVM
scripts to manage development VMs

More and more I use a Development VM (with AWS) instead of using my laptop. The beauty of it is I can choose the right size depending on what I need to do. I'm also not mudding my laptop with software that later is difficult to clean up - now I just need to destroy the VM and all is gone. In the past I used a local VM (with vagrant) but having it in the cloud makes easier to prepare it for release and access other cloud resources.

dvm.sh is a simple shell script that allows you to do all the operations in a VM. taking from the code\
echo "Usage:  $0 [help|create|destroy|start|stop|connect|upload file|download file|rupload dir|rdownload dir]"

myssh.sh is a subset of dvm.sh that I use to work with VMs from others. I just need to edit the DNS of the VM.\
echo "Usage:  $0 [help|connect|upload file|download file|rupload dir|rdownload dir]"

awsparams.sh declares all the AWS secrets needed. Use awsparams-template.sh to build it.

Enjoy!
