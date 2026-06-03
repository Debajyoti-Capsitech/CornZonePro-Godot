extends GPUParticles2D

@onready var dust_particles: GPUParticles2D = get_node_or_null("DustParticles")

func _process(_delta: float) -> void:
	if dust_particles and dust_particles.emitting != emitting:
		dust_particles.emitting = emitting
		if emitting:
			dust_particles.restart()
