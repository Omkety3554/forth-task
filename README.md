This task was based on monolithic application in a web server at private subnet
having bastion host in the public subnet acting as a vpn to access the webserver
the bastion is open to port 22 and locked with that of web server security group
also application load balancer was built in a public subnet with open port 443 and 80
which was also locked to that web-server security group
in this same environment we have tomcat install on our private instance 
