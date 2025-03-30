extends AnimatedSprite2D

var play_audio : bool = true

func _ready():
	play()
	
func _process(_delta):
	if get_frame() == 0 and play_audio == true:
		$PonteiroBrilho.play()
	
func play_anim(anim_name : String):
	$AnimationPlayer.play(anim_name)
	
func stop_anim():
	$AnimationPlayer.stop(true)

func set_label_text(stri : String):
	$Label.text = stri

func set_play_audio(opcao):
	play_audio = opcao
	
