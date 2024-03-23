
output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "bastion Server is firstinstance"
}



output "load_balancer_dns_name" {
  description = "Get load balancer name"
  value       = aws_lb.alb.dns_name
}