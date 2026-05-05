# Variables consumed by Terraform when run in CodePipeline/CodeBuild.
# Keep this file in git so pipeline runs are deterministic.
ecs_instance_type                     = "t3a.small"
ecs_asg_min_size                      = 1
ecs_asg_max_size                      = 4
ecs_asg_desired_capacity              = 2
ecs_capacity_provider_target_capacity = 100

services = {
	app = {
		image          = "408921634707.dkr.ecr.eu-west-2.amazonaws.com/warwick:katwebsite"
		container_port = 80
		desired_count  = 2
	}
	copy = {
		image             = "408921634707.dkr.ecr.eu-west-2.amazonaws.com/warwick:katwebsitecopy"
		container_port    = 80
		desired_count     = 1
		host_headers      = ["copy.localtest.me"]
		listener_priority = 110
	}
}
