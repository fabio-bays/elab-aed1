extends AnimatedSprite2D

func _ready():
	play()
	
func play_anim(anim_name : String):
	$AnimationPlayer.play(anim_name)
	
func stop_anim():
	$AnimationPlayer.stop(true)

func set_label_text(stri : String):
	$Label.text = stri
	
