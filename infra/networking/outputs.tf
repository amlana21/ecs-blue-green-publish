

output "task_sg_id" {
    value = aws_security_group.bg_ecs_task_sg.id
}

output "subnet_ids"{
    value = aws_subnet.bg_private.*.id
}

output "blue_tf_arn"{
    value = aws_lb_target_group.bg_lb_tg_blue.arn
}


output "green_tf_arn"{
    value = aws_lb_target_group.bg_lb_tg_green.arn
}

output "blue_tf_name"{
    value = aws_lb_target_group.bg_lb_tg_blue.name
}


output "green_tf_name"{
    value = aws_lb_target_group.bg_lb_tg_green.name
}

output "blue_listener_arn"{
    value = aws_lb_listener.bg_lb_listener_blue.arn
}

output "green_listener_arn"{
    value = aws_lb_listener.bg_lb_listener_green.arn
}

output "lb_name"{
    value = aws_lb.bg_lb.name
}
