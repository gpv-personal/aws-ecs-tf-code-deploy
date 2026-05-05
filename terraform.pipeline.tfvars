# Variables consumed by Terraform when run in CodePipeline/CodeBuild.
# Keep this file in git so pipeline runs are deterministic.
services = {
	app = {
		image          = "408921634707.dkr.ecr.eu-west-2.amazonaws.com/warwick:katwebsite"
		container_port = 80
		desired_count  = 2
		path_pattern   = "/*"
	}
	copy = {
		image             = "408921634707.dkr.ecr.eu-west-2.amazonaws.com/warwick:katwebsitecopy"
		container_port    = 8080
		desired_count     = 1
		path_pattern      = "/copy*"
		listener_priority = 110
	}
}
