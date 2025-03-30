extends Node2D

var pos_anterior : Vector2
var inserir_toggled_on : bool = false
var remover_toggled_on : bool = false

signal nodo_clicado(nodo_id, acao : int)
signal nodo_mouse_pairando(nodo_id, esta_pairando)
signal nodo_mudou_posicao(nodo_id, posicao)

var timer
var nodo_movendo : bool = false
	

func _ready():
	$Esfera.play()
	$Ponteiro.play()
	$Ponteiro.set_label_text('prox')
	$Esfera/AnimationPlayer.play('nodo_rotacionar')
	$Ponteiro/AnimationPlayer.play('ptr_rondar_nodo')
	
	pos_anterior = position

func _process(delta):
	if position != pos_anterior:
		pos_anterior = position
		nodo_movendo = true
	else:
		if nodo_movendo:
			nodo_mudou_posicao.emit(get_instance_id(), position)
			nodo_movendo = false
	
func _on_inserir_toggled():
	if !inserir_toggled_on:
		inserir_toggled_on = true
	else:
		inserir_toggled_on = false
		
func _on_remover_toggled():
	if !remover_toggled_on:
		remover_toggled_on = true
	else:
		remover_toggled_on = false

func _on_area_2d_mouse_entered():
	$Esfera/Area2D.connect('mouse_exited', _on_area_2d_mouse_exited)
	nodo_mouse_pairando.emit(get_instance_id(), true)
		

func _on_area_2d_mouse_exited():
	$Esfera/Area2D.disconnect('mouse_exited', _on_area_2d_mouse_exited)
	nodo_mouse_pairando.emit(get_instance_id(), false)

func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event.is_action_pressed("clique_esquerdo"):
		var nodo_id = get_instance_id()
		var esfera_area2d = $Esfera/Area2D

		if inserir_toggled_on:
			esfera_area2d.disconnect('mouse_exited', _on_area_2d_mouse_exited)
			nodo_clicado.emit(nodo_id, 1) # acao: 1 = inserir, 2 = remover
		elif remover_toggled_on:
			nodo_clicado.emit(nodo_id, 2) # acao: 1 = inserir, 2 = remover

func anim_info_esmaecer():
	$Esfera/Info/AnimationPlayer.play('info_esmaecer')
	return $Esfera/Info/AnimationPlayer
	
func anim_mover(distancia : int, sentido : int):
	await get_tree().create_tween().tween_property(
		self, 'position', self.position + sentido
		* Vector2(distancia, 0), 1).finished
	
func get_ponteiro_scene():
	return $Ponteiro
	
func esfera_stop_anim():
	$Esfera/AudioInsConcluida.play()
	await get_tree().create_tween().set_trans(Tween.TRANS_EXPO). \
		tween_method(
			$Esfera/AnimationPlayer.seek, 
			$Esfera/AnimationPlayer.get_current_animation_position(), 0, 1).finished
	$Esfera/AnimationPlayer.stop()

func anim_set_scale(new_scale : Vector2, anim_duracao : float):
	await get_tree().create_tween().tween_property(
		self, 'scale', new_scale, anim_duracao
	).finished 
	
func set_info(info : String):
	$Esfera/Info.text = info


