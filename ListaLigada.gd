extends Node

@export var nodo_scene : PackedScene
@export var bloco_codigo_scene : PackedScene
@export var ponteiro_scene : PackedScene
@export var parallax_bg_scene : PackedScene

@export var parallax_bg : Node2D
@export var ponteiro : AnimatedSprite2D

const FONTE_TEXTOS = preload('res://assets/fontes/VT323-Regular.ttf')
const VIEWPORT_SIZE = Vector2(320, 180)
const GRID_SIZE = Vector2(8, 8)
const NUMBER_OF_GRIDS = Vector2(VIEWPORT_SIZE / GRID_SIZE)
const NODO_COMP_X = 4 * GRID_SIZE.x
const DISPLAY_STRS : PackedStringArray = [
	'Nodo* inserir_pos_itr(Nodo *lista, int pos, int x)
	{
		if(pos > tam_lista(lista)) return lista;
		Nodo *novo = malloc(sizeof(Nodo));
		novo->info = x;

		if(lista == NULL || pos == 0){
			novo->prox = lista;
			lista = novo;
		} else{
			const int pos_do_anterior = 1;
			Nodo *aux = lista;
			Nodo *anterior;
			for(pos; pos > 0; pos--){
				if(pos == pos_do_anterior){
					anterior = aux;
					aux = aux->prox;
					anterior->prox = novo;
					novo->prox = aux;
				} else{
					aux = aux->prox;
				}
			}
		}
		return lista;
	}',
	'Nodo* remover_pos_itr(Nodo *lista, int pos)
	{
		if(lista == NULL || pos > tam_lista(lista)) return lista;
		Nodo *aux = lista;
		if(pos == 0){
			lista = lista->prox;
			free(aux);
		} else{
			const int pos_do_anterior = 1;
			Nodo *anterior;
			for(pos; pos > 0; pos--)
			{
				if(pos == pos_do_anterior){
					anterior = aux;
					aux = aux->prox;
					anterior->prox = aux->prox;
				} else{
					aux = aux->prox;
				}
			}
			free(aux);
		}
		return lista;
	}',
	'Nodo* inserir_pos_rec(Nodo *lista, int pos, int x)
	{
		if(pos > tam_lista(lista)) return lista;
		if(pos == 0){
			Nodo *novo = malloc(sizeof(Nodo));
			novo->info = x;
			novo->prox = lista;
			lista = novo;
		} else{
			lista->prox = inserir_pos_rec(lista->prox, pos - 1, x);
		}
		return lista;
	}',
	'Nodo* remover_pos_rec(Nodo *lista, int pos)
	{
		if(pos > tam_lista(lista)) return lista;
		if(pos == 0){
			Nodo *aux = lista;
			lista = lista->prox;
			free(aux);
		} else{
			lista->prox = remover_pos_rec(lista->prox, pos - 1);
		}
		return lista;
	}'
] # 0: inserir iterativamente. 1: remover iterativamente. 2: inserir recursivamente
	#+ 3: remover recursivamente
const CORES_RETANGULOS = ['7f0622', '00563d', '430067', '002859']
# Vermelho, verde, roxo, azul.

const COR_FUNDO_DEFAULT = '121116'
const POS_CANTO_TELA = Vector2(GRID_SIZE.x * 16, -GRID_SIZE.y * 8)
const DISTAN_PTR_NODO = Vector2(GRID_SIZE.x * 4, 0)

const ANIM_INTERVALO_DURACAO : float = 1.5 # em segundos
const ANIM_ANIMACAO_DURACAO : float = .5

var AudioListaLigada
var fator_velocidade_anim : float = 1
var label_fator_velo_anim : Label
var modo_animacao_iterativa 
var lista
var cam_focando_em_nodo_idx : int = 0
var animacao_esta_acontecendo : bool = false

signal inserir_toggled
signal remover_toggled

class Utilidades:
	static var rec_cor_anterior : Color = COR_FUNDO_DEFAULT
	static var fonte_textos : Font = FONTE_TEXTOS
	
	static func rec_set_rect(rec_rect, rec_rect_pos, cor):
		rec_rect_pos.y = - GRID_SIZE.y * 12
		rec_rect.position = rec_rect_pos
		rec_rect.size = Vector2(336, 192)
		rec_rect.color = Color(cor)

	static func rec_get_cor_entrando(pilha_cor, fila_cor):
		var cor = fila_cor.pop_front()
		
		pilha_cor.push_back(rec_cor_anterior)
		rec_cor_anterior = cor
		fila_cor.push_back(cor)
		
		return cor
		
	static func rec_get_cor_saindo(pilha_cor):
		var cor = pilha_cor.pop_back()
		rec_cor_anterior = cor
		return cor
		
	static func rec_gerar_label_pos() -> Label:
		var label = Label.new()
		label.add_theme_font_override('font', fonte_textos)
		label.add_theme_font_size_override('font_size', 14)
		label.add_theme_color_override('font_shadow_color', Color(0, 0, 0, 0.2))
		
		return label
		
class Lista:
	var lista : Dictionary
	var nulo_id : int
	
	## Primeiro e último nodo da lista visual apenas. No dicionário "lista", 
	## o último objeto é sempre o último a ser inserido.
	var primeiro_nodo_da_lista_id : int
	var ultimo_nodo_da_lista_id : int
	
	func set_nulo_id(nuloid : int):
		self.nulo_id = nuloid
		self.primeiro_nodo_da_lista_id = nuloid
		self.ultimo_nodo_da_lista_id = nuloid
		
	func _checar_se_null(obj : Variant):
		if obj == null:
			return self.nulo_id
		else:
			return obj

	func get_primeiro_nodo_id():
		return self.primeiro_nodo_da_lista_id
	func get_ultimo_nodo_id():
		return self.ultimo_nodo_da_lista_id
		
	func set_primeiro_nodo_id(x : int):
		self.primeiro_nodo_da_lista_id = x
	func set_ultimo_nodo_id(x : int):
		self.ultimo_nodo_da_lista_id = x
		
	func get_nodo_anterior_id_anim(nodo_clicado_id : int):
		## Obter o nodo anterior ao clicado. Como a animação de inserção é feita
		## após a inserção do objeto em "lista", o nodo anterior ao clicado fica
		## dois objetos para trás na estrutura de dados.
		if self.lista.has(nodo_clicado_id):
			return self.lista[lista[nodo_clicado_id]['ant']]['ant']
		else: # Assumindo que Nulo foi clicado (inserção na última posição),
			return self.lista[ultimo_nodo_da_lista_id]['ant']

	func push_nodo_id(nodo_novo_id : int, nodo_clicado_id):
		## A função insere o nodo, visualmente, na posição de nodo_clicado_id.
		if !self.lista.is_empty():
			self.lista[nodo_novo_id] = {'pos' : null, 'ant' : null,
										'idx' : null, 'posi' : null}
									
			var nodo_anterior_id 
			if nodo_clicado_id != self.nulo_id:
				nodo_anterior_id = self.lista[nodo_clicado_id]['ant']
				self.lista[nodo_clicado_id]['ant'] = nodo_novo_id
				self.lista[nodo_novo_id]['pos'] = nodo_clicado_id
				self.lista[nodo_novo_id]['idx'] = lista[nodo_clicado_id].get('idx')
			else:
				nodo_anterior_id = self.ultimo_nodo_da_lista_id
				self.lista[nodo_novo_id]['idx'] = lista[ultimo_nodo_da_lista_id].get('idx') + 1
				self.ultimo_nodo_da_lista_id = nodo_novo_id
				self.lista[nodo_novo_id]['pos'] = null
			
			if nodo_anterior_id != null:
				self.lista[nodo_anterior_id]['pos'] = nodo_novo_id
				self.lista[nodo_novo_id]['ant'] = nodo_anterior_id
			else: 	
				self.primeiro_nodo_da_lista_id = nodo_novo_id
			
			self.lista[nodo_novo_id]['posi'] = instance_from_id(
				nodo_novo_id).position
			
			atualizar_nodos_idx_e_posicoes(nodo_novo_id, true) 
		else:
			self.lista[nodo_novo_id] = {'pos' : null, 'ant' : null, 'idx' : 0}
			self.primeiro_nodo_da_lista_id = nodo_novo_id
			self.ultimo_nodo_da_lista_id = nodo_novo_id

	func get_primeiro_nodo_id_pre_insercao():
		## Obter o id do antigo primeiro nodo. Como a animação de inserção é feita
		## após a inserção do objeto em "lista", o primeiro nodo para a animação
		## é posterior ao objeto inserido.
		var primeiro_nodo_id = self.get_primeiro_nodo_id()
		if primeiro_nodo_id == self.get_ultimo_nodo_inserido_id():
			primeiro_nodo_id = self.get_nodo_posterior_id(primeiro_nodo_id)
		if primeiro_nodo_id == null:
			primeiro_nodo_id = self.get_nulo_id()

		return primeiro_nodo_id

	func erase_nodo_id(nodo_id):
		if nodo_id != nulo_id:
			var nodo_anterior_id = self.lista[nodo_id]['ant']
			var nodo_posterior_id = self.lista[nodo_id]['pos']
			
			if nodo_anterior_id != null:
				self.lista[nodo_anterior_id]['pos'] = self.lista[nodo_id]['pos']
			if nodo_posterior_id != null:
				self.lista[nodo_posterior_id]['ant'] = self.lista[nodo_id]['ant']
			if nodo_id == self.ultimo_nodo_da_lista_id:
				self.ultimo_nodo_da_lista_id = self._checar_se_null(nodo_anterior_id)
			if nodo_id == self.primeiro_nodo_da_lista_id:
				self.primeiro_nodo_da_lista_id = self._checar_se_null(nodo_posterior_id)
			
			atualizar_nodos_idx_e_posicoes(nodo_id, false)
			self.lista.erase(nodo_id)
		
	func get_nodo_posterior_id(nodo_atual_id : int):
		return self.lista[nodo_atual_id]['pos']
	func get_nodo_anterior_id(nodo_atual_id : int):
		return self.lista[nodo_atual_id]['ant']
	func get_nulo_id():
		return self.nulo_id
		
	func get_ultimo_nodo_inserido_id():
		return lista.keys()[-1]
		
	func duplicate():
		var lista_copia = Lista.new()
		lista_copia.lista = lista.duplicate()
		lista_copia.primeiro_nodo_da_lista_id = self.primeiro_nodo_da_lista_id
		lista_copia.ultimo_nodo_da_lista_id = self.ultimo_nodo_da_lista_id
		lista_copia.nulo_id = self.nulo_id
		
		return lista_copia

	func get_elementos_id():
		return lista.keys()

	func atualizar_nodos_idx_e_posicoes(nodo_id, foi_insercao : bool):
		var fator
		if foi_insercao:
			fator = +1
		else:
			fator = -1
			
		var nodo_posterior_id = self.get_nodo_posterior_id(nodo_id)
		while nodo_posterior_id != null:
			self.lista[nodo_posterior_id]['idx'] += fator * 1
			nodo_posterior_id = self.get_nodo_posterior_id(nodo_posterior_id)

	func get_nodo_id_idx(nodo_id):
		return self.lista[nodo_id]['idx']

	func atualizar_dict_posicao(nodo_id, nova_pos):
		self.lista[nodo_id]['posi'] = nova_pos
	
	func _find_idx_key(idx):
		for key in self.lista:
			if self.lista[key]['idx'] == idx:
				return key
				
	func get_idx_posi(idx : int):
		return self.lista[self._find_idx_key(idx)]['posi']
		
	func get_tamanho():
		return self.lista.size()

func _ready():
	set_label_fator_velo_anim()
	ponteiro.set_label_text('Lista')
	$Nulo.add_user_signal('nulo_clicado', [null, 'acao'])
	$Nulo.connect('nulo_clicado', _on_nodo_ou_nulo_clicado)
	anim_o_comeco()
	lista = Lista.new()
	lista.set_nulo_id($Nulo.get_instance_id())
	AudioListaLigada = get_node('AudioListaLigada')
	AudioListaLigada.play_mus('idle')
	modo_animacao_iterativa = true

func _process(_delta):
	if lista.lista.is_empty(): 
		$Camera2D/Botoes/Remover.button_pressed = false

	if Input.is_anything_pressed():
		if !animacao_esta_acontecendo and lista.get_tamanho() != 0:
			if Input.is_action_just_pressed('ui_left'):
				set_cam_foco_nodo('esq', null)
				await AudioListaLigada.play_sfx('user_mv_esq')
			elif Input.is_action_just_pressed('ui_right'):
				set_cam_foco_nodo('dir', null)
				await AudioListaLigada.play_sfx('user_mv_dir')

func _on_iterativo_toggled(toggled_on):
	var iterativo_button = $Camera2D/Botoes/Iterativo
	var recursivo_button = $Camera2D/Botoes/Recursivo
	if toggled_on:
		if recursivo_button.button_pressed:
			recursivo_button.button_pressed = false
		modo_animacao_iterativa = true
	else:
		if !recursivo_button.button_pressed:
			iterativo_button.button_pressed = true

func _on_recursivo_toggled(toggled_on):
	var iterativo_button = $Camera2D/Botoes/Iterativo
	var recursivo_button = $Camera2D/Botoes/Recursivo
	if toggled_on:
		if iterativo_button.button_pressed:
			iterativo_button.button_pressed = false
		modo_animacao_iterativa = false
	else:
		if !iterativo_button.button_pressed:
			recursivo_button.button_pressed = true

func _on_inserir_toggled(toggled_on):
	var inserir_button = $Camera2D/Botoes/Inserir
	var remover_button = $Camera2D/Botoes/Remover
	
	inserir_toggled.emit()
	if toggled_on:
		if lista.lista.is_empty():
			inserir_nodo()
			toggled_on = false
			trocar_visibilidade_botoes(false)
			await anim_insercao_nodo()
			inserir_button.set_pressed_no_signal(false)
			trocar_visibilidade_botoes(true)
		if remover_button.button_pressed:
			remover_button.button_pressed = false

func _on_remover_toggled(toggled_on):
	var inserir_button = $Camera2D/Botoes/Inserir
	var remover_button = $Camera2D/Botoes/Remover
	
	remover_toggled.emit()
	
	if toggled_on:
		if inserir_button.button_pressed:
			inserir_button.button_pressed = false
		if lista.lista.is_empty():
			remover_button.button_pressed = false

func _on_acelerar_pressed():
	match fator_velocidade_anim:
		4.0:
			fator_velocidade_anim = 2.0 #0.5x
		2.0:
			fator_velocidade_anim = 1.33 #0.75x
		1.33:
			fator_velocidade_anim = 1.0
		1.0:
			fator_velocidade_anim = 0.8 #1.25x
		0.8:
			fator_velocidade_anim = 0.665 #1.5x
		0.665: 
			fator_velocidade_anim = 0.57 #1.75x
		0.57:
			fator_velocidade_anim = 0.5 #2x
		0.5:
			fator_velocidade_anim = 0.25 #4x
	label_fator_velo_anim.text = "%.2f" % (1/fator_velocidade_anim) + 'x'

func _on_desacelerar_pressed():
	match fator_velocidade_anim:
		0.25:
			fator_velocidade_anim = 0.5 #2x
		0.5:
			fator_velocidade_anim = 0.57 #1.75x
		0.57:
			fator_velocidade_anim = 0.665 #1.5x
		0.665: 
			fator_velocidade_anim = 0.8 #1.25x
		0.8:
			fator_velocidade_anim = 1 #1x
		1.0:
			fator_velocidade_anim = 1.33 #0.75x
		1.33:
			fator_velocidade_anim = 2.0 #0.5x
		2.0: 
			fator_velocidade_anim = 4 #0.25x
	label_fator_velo_anim.text = "%.2f" % (1/fator_velocidade_anim) + 'x'

func _on_pausar_toggled(toggled_on):
	get_tree().paused = !get_tree().paused
	
func _on_nodo_ou_nulo_clicado(nodo_clicado_id, acao):
	# Se nulo foi clicado, nodo_clicado_id = nulo_id
	if !animacao_esta_acontecendo:
		if acao == 1:
			inserir_toggled.emit()
			trocar_visibilidade_botoes(false)
			inserir_nodo(nodo_clicado_id)
			await anim_insercao_nodo(nodo_clicado_id)
			$Camera2D/Botoes/Inserir.set_pressed_no_signal(false)
			trocar_visibilidade_botoes(true)
		elif acao == 2:
			if nodo_clicado_id != lista.get_nulo_id():
				$RemoverX.visible = false
				trocar_visibilidade_botoes(false)
				await anim_remocao_nodo(nodo_clicado_id)
				remover_nodo(nodo_clicado_id)
				$Camera2D/Botoes/Remover.button_pressed = false
				trocar_visibilidade_botoes(true)

func _on_nodo_mouse_pairando(nodo_id, esta_pairando):
	var remover_button = $Camera2D/Botoes/Remover
	if remover_button.button_pressed and remover_button.visible:
		var nodo_mouse_pairando = instance_from_id(nodo_id)
		var remover_x = $RemoverX
		if esta_pairando:
			remover_x.position = nodo_mouse_pairando.position
			remover_x.visible = true
			remover_x.play('mouse_entrou')
		else:
			remover_x.position = nodo_mouse_pairando.position
			remover_x.visible = true
			remover_x.play('mouse_saiu')

func _on_nulo_area_2d_input_event(_viewport, event, _shape_idx):
	if event.is_action_pressed("clique_esquerdo"):
		if $Camera2D/Botoes/Inserir.button_pressed:
			$Nulo.emit_signal('nulo_clicado', lista.get_nulo_id(), 1)
		elif $Camera2D/Botoes/Remover.button_pressed:
			$Nulo.emit_signal('nulo_clicado', lista.get_nulo_id(), 2)

func set_label_fator_velo_anim():
	label_fator_velo_anim = Label.new()
	label_fator_velo_anim.visible = false
	label_fator_velo_anim.add_theme_font_override('font', FONTE_TEXTOS)
	label_fator_velo_anim.position = $Camera2D.position + \
									Vector2(16 * GRID_SIZE.x, 
											GRID_SIZE.y * 4.5)
	label_fator_velo_anim.add_theme_font_size_override('font_size', 12)
	label_fator_velo_anim.set_text(str(fator_velocidade_anim) + 'x')
	$Camera2D.add_child(label_fator_velo_anim)

func inserir_nodo(nodo_clicado_id = null):
	var nodo = nodo_scene.instantiate()
	var nodo_novo_id = nodo.get_instance_id()
	
	lista.push_nodo_id(nodo_novo_id, nodo_clicado_id)
	
	inserir_toggled.connect(nodo._on_inserir_toggled)
	remover_toggled.connect(nodo._on_remover_toggled)
	nodo.nodo_mudou_posicao.connect(lista.atualizar_dict_posicao)
	nodo.nodo_clicado.connect(_on_nodo_ou_nulo_clicado)
	nodo.nodo_mouse_pairando.connect(_on_nodo_mouse_pairando)

	
func remover_nodo(nodo_clicado_id):
	remove_child(instance_from_id(nodo_clicado_id))
	
func display_bloco_codigo():
	var bloco_codigo = bloco_codigo_scene.instantiate()
	
	bloco_codigo.set_position(
		bloco_codigo.position - Vector2(
			((NUMBER_OF_GRIDS.x / 2) - 1) * GRID_SIZE.x
			,
			(((NUMBER_OF_GRIDS.y) / 2) - 13) * GRID_SIZE.y
		)
	)

	if $Camera2D/Botoes/Inserir.button_pressed:
		if modo_animacao_iterativa:
			bloco_codigo.display_str = DISPLAY_STRS[0]
		else:
			bloco_codigo.display_str = DISPLAY_STRS[2]
	elif $Camera2D/Botoes/Remover.button_pressed:
		if modo_animacao_iterativa:
			bloco_codigo.display_str = DISPLAY_STRS[1]
		else:
			bloco_codigo.display_str = DISPLAY_STRS[3]

	$Camera2D.add_child(bloco_codigo)
	return bloco_codigo
	
func remover_bloco_codigo(bloco_codigo):
	$Camera2D.remove_child(bloco_codigo)

func trocar_visibilidade_botoes(visibilidade : bool):
	$Camera2D/Botoes/Remover.visible = visibilidade
	$Camera2D/Botoes/Inserir.visible = visibilidade
	$Camera2D/Botoes/Recursivo.visible = visibilidade
	$Camera2D/Botoes/Iterativo.visible = visibilidade
	$Camera2D/Botoes/Acelerar.visible = !visibilidade
	$Camera2D/Botoes/Desacelerar.visible = !visibilidade
	$Camera2D/Botoes/Pausar.visible = !visibilidade
	label_fator_velo_anim.visible = !visibilidade

func set_cam_foco_nodo(op : String, nodo_id = null):
	if op == 'esq':
		cam_focando_em_nodo_idx -= 1
		if cam_focando_em_nodo_idx == -1:
			cam_focando_em_nodo_idx = lista.get_tamanho()
			anim_mover_cam($Nulo.position)
		else:
			anim_mover_cam(lista.get_idx_posi(cam_focando_em_nodo_idx))
	elif op == 'dir' and lista.get_tamanho() > 0:
		cam_focando_em_nodo_idx += 1
		if cam_focando_em_nodo_idx == lista.get_tamanho():
			anim_mover_cam($Nulo.position)
		elif cam_focando_em_nodo_idx == lista.get_tamanho() + 1:
			cam_focando_em_nodo_idx = 0
			anim_mover_cam(lista.get_idx_posi(cam_focando_em_nodo_idx))
		else:
			anim_mover_cam(lista.get_idx_posi(cam_focando_em_nodo_idx))
	elif op == 'nd_novo' and nodo_id != null:
		cam_focando_em_nodo_idx = lista.get_nodo_id_idx(nodo_id)
		anim_mover_cam(lista.get_idx_posi(cam_focando_em_nodo_idx))
	elif op == 'rm_nodo':
		if nodo_id != null:
			cam_focando_em_nodo_idx = lista.get_nodo_id_idx(nodo_id)
			anim_mover_cam(lista.get_idx_posi(cam_focando_em_nodo_idx))
		else:
			anim_mover_cam($Nulo.position)

func anim_o_comeco():
	var scene_tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO)
	scene_tween.tween_property($Nulo, "scale", Vector2(1.5,1.5), 1).from(Vector2(0,0))
	$Nulo.play()
	ponteiro.play()
	scene_tween.tween_property(ponteiro, "visible", true, 1e-9).from(false)
	scene_tween.tween_property(ponteiro, "scale", Vector2(1.5, 1.5), 0.5).from(
		Vector2(0.2,0.2))

func anim_nodo_novo(nodo, bloco_codigo):
	
	await anim_bloco_codigo_highlight_str(
		bloco_codigo, ['Nodo *novo = malloc(sizeof(Nodo));', 1]
	)
	get_tree().create_tween().set_parallel().tween_property(
		nodo, 'visible', true, 1e-9
	)
	nodo.get_ponteiro_scene().set_play_audio(true)
	await AudioListaLigada.play_sfx('surgir')
	await get_tree().create_tween().tween_property(
	nodo, "scale", Vector2(1, 1), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim / 2).from(Vector2(0.3,0.3)).finished

	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim * 2)

	await anim_bloco_codigo_highlight_str(bloco_codigo, 
		['novo->info = x;', 1])

	await nodo.anim_info_esmaecer().animation_finished	#padronizar? -> ao invés de chamar
														#+ um método da cena, extrair o objeto
														#+ da cena e aplicar o tweener?

	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
func anim_inserir_itr_nodo_novo(nodo, bloco_codigo):
		await anim_nodo_novo(nodo, bloco_codigo)
		await anim_bloco_codigo_highlight_str(bloco_codigo, 
											['if(lista == NULL || pos == 0)', 1])

func anim_inserir_rec_nodo_novo(nodo, bloco_codigo):
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['if(pos == 0)', 1])
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)

	await anim_nodo_novo(nodo, bloco_codigo)
	await get_tree().create_tween().tween_property(
		$Camera2D, 'position', 
		$Camera2D.position - Vector2(2 * NODO_COMP_X, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
		).finished
	
func anim_inserir_no_inicio(nodo, bloco_codigo, apontar_para_id, 
								ponteiro_cabeca): 
	var apontar_para = instance_from_id(apontar_para_id)
	var nodo_ponteiro = nodo.get_ponteiro_scene()
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['novo->prox = lista;', 1])
	## Animação: fazer nodo aproximar-se da posição desejada
	await get_tree().create_tween().tween_property(nodo, "position", 
													apontar_para.position
													- Vector2(
														0, GRID_SIZE.y
														* 7), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	nodo_ponteiro.stop_anim()
	## Animação: fazer ponteiro do nodo apontar
	await anim_ptr_apontar(nodo_ponteiro,
							Vector2(0, GRID_SIZE.y * 4), 
							90)
	
	## Animação: fazer o ponteiro na horizontal apontar
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['lista = novo;', 1])
	
	await AudioListaLigada.play_sfx('ptr_mv')
	await get_tree().create_tween().tween_property(
		ponteiro_cabeca, "position", nodo.position - Vector2(
			GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	
	## Animação: comportar na corrente o nodo, seu ponteiro, e o ponteiro na horizontal
	var move_tudo_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC). \
		set_parallel()
	move_tudo_tween.tween_property(nodo, "position", apontar_para.position
								- Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	move_tudo_tween.tween_property(nodo_ponteiro, "rotation", 0, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	move_tudo_tween.tween_property(nodo_ponteiro, "position", 
								Vector2(GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	await move_tudo_tween.tween_property(
		ponteiro_cabeca, "global_position", apontar_para.position
		- Vector2(GRID_SIZE.x * 12, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	nodo.force_update_transform()

func anim_inserir_itr_no_meio(nodo_novo, bloco_codigo, nodo_clicado_id, 
								nodo_anterior_id, ptr_lista_copia):
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['else', 1])

	var nodo_anterior = instance_from_id(nodo_anterior_id)
	var rect_nodo = $RectNodo
	rect_nodo.position.x = nodo_anterior.position.x \
								- GRID_SIZE.x * 2
	rect_nodo.visible = false
	
	var ponteiro_aux = ponteiro_scene.instantiate()
	var ponteiro_anterior = ponteiro_scene.instantiate()
	
	await anim_itr_no_meio_pos_dif_zero(nodo_clicado_id, bloco_codigo,
										ponteiro_anterior, true, rect_nodo, 
										ponteiro_aux, nodo_novo)
	
	## Animação: retângulo no nodo centralizado e surgimento de "pos ="
	var resultado = await anim_itr_rect_nodo_centralizado()
	var rect_nodo_centralizado = resultado[0]
	var pos_label = resultado[1]
	
	## Animação: Retângulo centralizando nodos diferentes a cada iteração
	var nodo_centralizado_id = lista.get_primeiro_nodo_id()
	while nodo_centralizado_id != nodo_clicado_id:
		await anim_bloco_codigo_highlight_str(bloco_codigo, 
											['for(pos; pos > 0; pos--)', 1])
		await anim_bloco_codigo_highlight_str(bloco_codigo, 
											['if(pos == pos_do_anterior)', 1])

		if nodo_centralizado_id == nodo_anterior_id:
			await anim_inserir_itr_no_meio_pos_igual_pos_anterior(
				rect_nodo, 
				rect_nodo_centralizado,
				bloco_codigo,
				nodo_clicado_id,
				nodo_centralizado_id,
				ponteiro_anterior,
				ponteiro_aux, ptr_lista_copia, nodo_novo,
				nodo_anterior)
			break
		else:
			nodo_centralizado_id = lista.get_nodo_posterior_id(nodo_centralizado_id)
			var prox_nodo_centralizado = instance_from_id(nodo_centralizado_id)
			
			await anim_itr_no_meio_pos_dif_pos_anterior(
				bloco_codigo, ponteiro_aux, rect_nodo_centralizado, 
				prox_nodo_centralizado, ponteiro_anterior, nodo_novo)

	return [ponteiro_aux, ponteiro_anterior]

func anim_insercao_nodo(nodo_clicado_id = null):
	AudioListaLigada.play_mus('algor')
	
	animacao_esta_acontecendo = true
	
	var nodo_novo = instance_from_id(lista.get_ultimo_nodo_inserido_id()) 
	var bloco_codigo = display_bloco_codigo()
	var pilha_cor : Array = []
	var fila_cor : Array = CORES_RETANGULOS.duplicate()
	var ptr_lista_copia = ponteiro_scene.instantiate()
	var rec_rect = ColorRect.new()
	var random_number_g = RandomNumberGenerator.new()
	random_number_g.randomize()
	var random_number : int = random_number_g.randi_range(0, 100)
	var label_x_random : Label 
	label_x_random = Utilidades.rec_gerar_label_pos()
	label_x_random.set_text('x = ' + str(random_number))
	rec_rect.visible = false
	add_child(rec_rect)
	move_child(rec_rect, 0)
	
	if modo_animacao_iterativa:
		var ponteiro_aux = null
		var ponteiro_anterior = null
		nodo_novo.visible = false
		add_child(nodo_novo)
		nodo_novo.get_ponteiro_scene().set_play_audio(false)
		nodo_novo.set_info(str(random_number))
		
		if cam_focando_em_nodo_idx != 0:
			await anim_cam_focar_objeto(
				instance_from_id(lista.get_primeiro_nodo_id_pre_insercao())
			)
		await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo, ponteiro, 
								rec_rect, ptr_lista_copia)
		await anim_x_info(label_x_random)
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		await anim_cam_focar_objeto(
			instance_from_id(lista.get_primeiro_nodo_id_pre_insercao()), 
			'suave'
		)
		anim_set_novo_nodo_pos(nodo_novo)
		await anim_inserir_itr_nodo_novo(nodo_novo, bloco_codigo)
		
		if nodo_clicado_id == null:
			await get_tree().create_tween().tween_property(
				$Camera2D, 'position', $Camera2D.position - 2 * DISTAN_PTR_NODO,
				ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
			).finished
			await anim_inserir_no_inicio(nodo_novo, bloco_codigo, lista.get_nulo_id(), 
										ptr_lista_copia)
		
		else:
			var nodo_anterior_id = lista.get_nodo_anterior_id_anim(nodo_clicado_id)
		
			if nodo_anterior_id == null:
				await get_tree().create_tween().tween_property(
					$Camera2D, 'position', $Camera2D.position - 2 * DISTAN_PTR_NODO,
					ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
				).finished
				await anim_inserir_no_inicio(nodo_novo, bloco_codigo, nodo_clicado_id,
											ptr_lista_copia)
			else:
				var resultado = await anim_inserir_itr_no_meio(
					nodo_novo, bloco_codigo, nodo_clicado_id, nodo_anterior_id,
					ptr_lista_copia
				)
				
				ponteiro_aux = resultado[0]
				ponteiro_anterior = resultado[1]

		await anim_itr_return(ponteiro_aux, ponteiro_anterior, bloco_codigo)
		await anim_rec_return(rec_rect, ptr_lista_copia, fila_cor, pilha_cor, 
								bloco_codigo, ponteiro, true)
		await nodo_novo.esfera_stop_anim()
		
		for node in get_tree().get_nodes_in_group('nodos_anteriores_ao_clicado'):
			node.remove_from_group('nodos_anteriores_ao_clicado')
	else:
		var label_pos = Utilidades.rec_gerar_label_pos()
		nodo_novo.visible = false
		add_child(nodo_novo)
		nodo_novo.get_ponteiro_scene().set_play_audio(false)
		nodo_novo.set_info(str(random_number))
		
		if cam_focando_em_nodo_idx != 0:
			await anim_cam_focar_objeto(instance_from_id(
				lista.get_primeiro_nodo_id_pre_insercao()
				)
			)

		label_pos.visible = false
		label_pos.position = Vector2(13 * GRID_SIZE.x, -9 * GRID_SIZE.y)
		$Camera2D.add_child(label_pos)

		if nodo_clicado_id == null:
			await anim_rec_inserir_no_comeco(nodo_novo, pilha_cor, fila_cor,
				bloco_codigo, rec_rect, ptr_lista_copia, lista.get_nulo_id(),
				label_pos, label_x_random)
		else:
			var nodo_anterior_ao_clic_id = lista.get_nodo_anterior_id_anim(nodo_clicado_id)
			if nodo_anterior_ao_clic_id == null:
				await anim_rec_inserir_no_comeco(nodo_novo, pilha_cor, fila_cor,
					bloco_codigo, rec_rect, ptr_lista_copia, nodo_clicado_id,
					label_pos, label_x_random)
			else:
				await anim_rec_inserir_no_meio(nodo_anterior_ao_clic_id, pilha_cor, 
												fila_cor, bloco_codigo, 
												rec_rect, ptr_lista_copia, 
												nodo_novo, nodo_clicado_id, label_pos,
												label_x_random)
	
	set_cam_foco_nodo('nd_novo', lista.get_ultimo_nodo_inserido_id())
	remover_bloco_codigo(bloco_codigo)
	ptr_lista_copia.queue_free()
	rec_rect.queue_free()
	
	AudioListaLigada.reset_sfx()
	AudioListaLigada.play_mus('idle')
	animacao_esta_acontecendo = false
	
func anim_remocao_nodo(nodo_clicado_id):
	AudioListaLigada.play_mus('algor')
	animacao_esta_acontecendo = true
	
	var bloco_codigo = display_bloco_codigo()
	var nodo_anterior_id = lista.get_nodo_anterior_id(nodo_clicado_id)
	var resultado : Array
	var pilha_cor : Array = []
	var fila_cor : Array = CORES_RETANGULOS.duplicate()
	var ptr_lista_copia = ponteiro_scene.instantiate()
	var rec_rect = ColorRect.new()
	rec_rect.visible = false
	add_child(rec_rect)
	move_child(rec_rect, 0)
	
	if modo_animacao_iterativa:
		var ponteiro_aux : Variant = null
		var ponteiro_anterior : Variant = null
		
		if cam_focando_em_nodo_idx != 0:
			await anim_cam_focar_objeto(instance_from_id(lista.get_primeiro_nodo_id()))
		await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo, ponteiro,
								rec_rect, ptr_lista_copia)
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		await anim_cam_focar_objeto(instance_from_id(lista.get_primeiro_nodo_id()),
									'suave')
								
		if nodo_anterior_id == null:
			ponteiro_aux = await anim_remover_itr_primeira_pos(bloco_codigo, 
																nodo_clicado_id,
																ptr_lista_copia)
		else:
			resultado = await anim_remover_itr_no_meio(bloco_codigo, nodo_clicado_id,
														ptr_lista_copia)
			ponteiro_aux = resultado[0]
			ponteiro_anterior = resultado[1]
			
		await anim_itr_return(ponteiro_aux, ponteiro_anterior, bloco_codigo)
		await anim_rec_return(rec_rect, ptr_lista_copia, fila_cor, pilha_cor, 
								bloco_codigo, ponteiro, false)

		for nodes in get_tree().get_nodes_in_group('nodos_anteriores_ao_clicado'):
			nodes.remove_from_group('nodos_anteriores_ao_clicado')
	else:
		var label_pos = Utilidades.rec_gerar_label_pos()
		rec_rect.visible = false
		add_child(rec_rect)
		move_child(rec_rect, 0)
		
		if cam_focando_em_nodo_idx != 0:
			await anim_cam_focar_objeto(instance_from_id(
				lista.get_primeiro_nodo_id()))

		label_pos.visible = false
		label_pos.position = Vector2(13 * GRID_SIZE.x, -9 * GRID_SIZE.y)
		$Camera2D.add_child(label_pos)
		
		if nodo_anterior_id == null:
			label_pos.text = 'pos = 0'
			label_pos.set_modulate(Color(1, 1, 1, 0))
			label_pos.visible = true
			await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo, ponteiro,
								rec_rect, ptr_lista_copia)
			await anim_esmaecer(label_pos, true)
			
			await anim_rec_remover_pos_zero(bloco_codigo, ptr_lista_copia, 
											nodo_clicado_id)
			await anim_rec_return(rec_rect, ptr_lista_copia, fila_cor, pilha_cor,
									bloco_codigo, ponteiro, false, [label_pos, 0])
		else:
			await anim_rec_remover_do_meio(nodo_clicado_id, nodo_anterior_id, 
											pilha_cor, fila_cor, bloco_codigo,
											rec_rect, ptr_lista_copia, label_pos)

	lista.erase_nodo_id(nodo_clicado_id)
	
	set_cam_foco_nodo('rm_nodo', nodo_anterior_id)
	remover_bloco_codigo(bloco_codigo)
	
	AudioListaLigada.reset_sfx()
	AudioListaLigada.play_mus('idle')
	animacao_esta_acontecendo = false

func anim_x_info(label):
	label.position = $Camera2D.position + Vector2(0, GRID_SIZE.y * 10)
	label.set_modulate(Color(1,1,1,0))
	add_child(label)

	get_tree().create_tween().set_parallel(true).tween_property(
		label, 'modulate', Color(1,1,1,1), 
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	)
	await get_tree().create_tween().tween_property(
		label, 'position', label.position + Vector2(0, -GRID_SIZE.y * 2.5),
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).finished
	
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	get_tree().create_tween().set_parallel(true).tween_property(
		label, 'modulate', Color(1,1,1,0), 
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	)
	await get_tree().create_tween().tween_property(
		label, 'position', label.position + Vector2(0, -GRID_SIZE.y * 2),
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).finished
	
func anim_remover_itr_primeira_pos(bloco_codigo, nodo_clicado_id, ptr_lista_copia):
	var ponteiro_aux = ponteiro_scene.instantiate()
	var nodo_clicado = instance_from_id(nodo_clicado_id)
	var nodo_posterior_id = lista.get_nodo_posterior_id(nodo_clicado_id)
	var nodo_posterior : Variant
	if nodo_posterior_id != null:
		nodo_posterior = instance_from_id(nodo_posterior_id)
	else:
		nodo_posterior = $Nulo
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['Nodo *aux = lista;', 1])
	
	await anim_ptr_surgir(ponteiro_aux, $Camera2D.position + Vector2(
						GRID_SIZE.x * 16, -GRID_SIZE.y * 8) , 'aux')
						
	await anim_ptr_apontar(ponteiro_aux, instance_from_id(
								lista.get_primeiro_nodo_id()
							).position + Vector2(
								0, GRID_SIZE.y * 4), -90)
	
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['if(pos == 0)', 1])
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['lista = lista->prox;', 1])
	
	await anim_ptr_apontar(ptr_lista_copia, 
							nodo_posterior.position + Vector2(0, -GRID_SIZE.y * 4), 90)

	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['free(aux)', 1])	
	
	await anim_nodo_ascender(nodo_clicado)

	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	AudioListaLigada.play_sfx('esmaecer')
	await anim_esmaecer(nodo_clicado)

	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	ponteiro_aux.play_anim('girar_em_torno_de_si_mesmo')

	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_apontar(ptr_lista_copia,
						 nodo_posterior.position + Vector2(
							-GRID_SIZE.x * 4, 0), 0)

	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['return lista;', 2])
										
	return ponteiro_aux
	
func anim_remover_itr_no_meio(bloco_codigo, nodo_clicado_id, ptr_lista_copia) -> Array:
	var ponteiro_anterior = ponteiro_scene.instantiate()
	var ponteiro_aux = ponteiro_scene.instantiate()
	var nodo_anterior_id = lista.get_nodo_anterior_id(nodo_clicado_id)
	var nodo_anterior = instance_from_id(nodo_anterior_id)
	var rect_nodo = $RectNodo
	rect_nodo.position.x = nodo_anterior.position.x \
								- GRID_SIZE.x * 2
	rect_nodo.visible = true
	
	await anim_itr_no_meio_pos_dif_zero(nodo_clicado_id, bloco_codigo,
										ponteiro_anterior, false, rect_nodo, 
										ponteiro_aux, null)
		
	## Animação: retângulo no nodo centralizado e surgimento de "pos ="
	var resultado = await anim_itr_rect_nodo_centralizado()
	var rect_nodo_centralizado = resultado[0]
	var pos_label = resultado[1]
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['for(pos; pos > 0; pos--)', 1])

	## Animação: Retângulo centralizando nodos diferentes a cada iteração
	var nodo_centralizado_id = lista.get_primeiro_nodo_id()
	while nodo_centralizado_id != nodo_clicado_id:
		await anim_bloco_codigo_highlight_str(bloco_codigo, 
											['if(pos == pos_do_anterior)', 1])

		if nodo_centralizado_id == nodo_anterior_id:
			var nodo_clicado = instance_from_id(nodo_clicado_id)
			var nodo_centralizado = instance_from_id(nodo_centralizado_id)
			var nodo_anterior_ptr = nodo_anterior.get_ponteiro_scene()
			var nodo_posterior
			if lista.get_nodo_posterior_id(nodo_clicado_id) == null: 
				nodo_posterior = $Nulo
			else:
				nodo_posterior = instance_from_id(lista.get_nodo_posterior_id(nodo_clicado_id))
				
			await anim_itr_no_meio_preparar_aux_e_anterior(
				rect_nodo, rect_nodo_centralizado, bloco_codigo, nodo_clicado,
				nodo_centralizado, ponteiro_anterior, ponteiro_aux 
			)
			
			await anim_bloco_codigo_highlight_str(bloco_codigo, 
									['anterior->prox = aux->prox;', 1])

			await anim_ptr_apontar(
				nodo_anterior_ptr,
				nodo_posterior.position - Vector2(
					0, GRID_SIZE.x * 4), 90, true)
					
			await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
			
			await anim_bloco_codigo_highlight_str(bloco_codigo, ['free(aux)', 2])	
			
			await anim_nodo_ascender(nodo_clicado)

			await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
			
			$AudioListaLigada.play_sfx('esmaecer')
			await anim_esmaecer(nodo_clicado)
			
			await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
			
			ponteiro_aux.play_anim('girar_em_torno_de_si_mesmo')
			
			await anim_ptr_apontar(nodo_anterior_ptr,
								 Vector2(GRID_SIZE.x * 4, 0), 0)
			
			await anim_itr_mover_anteriores(nodo_anterior_id, ponteiro_anterior,
											ptr_lista_copia, 'dir')
			
			break
		else:
			nodo_centralizado_id = lista.get_nodo_posterior_id(nodo_centralizado_id)
			var prox_nodo_centralizado = instance_from_id(nodo_centralizado_id)
			
			await anim_itr_no_meio_pos_dif_pos_anterior(
				bloco_codigo, ponteiro_aux, rect_nodo_centralizado, 
				prox_nodo_centralizado, ponteiro_anterior)
				
			await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
			
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
							['return lista;', 2])
	
	return [ponteiro_aux, ponteiro_anterior]
		
func anim_esmaecer(objeto, inverso : bool = false):
	if !inverso:
		await get_tree().create_tween().tween_method(objeto.set_modulate,
													objeto.modulate, Color(1, 1, 1, 0),
													ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	else:
		await get_tree().create_tween().tween_method(objeto.set_modulate,
											objeto.modulate, Color(1, 1, 1, 1),
											ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	
func anim_itr_num_pos_nodos_rev(nodo_clicado_id, nodo_novo = null):
	## Animação: surgimento dos números denotando a posição de nodos
	var itr_nodo_id = nodo_clicado_id
	var colocar_no_grupo = false
	var i = 0
	while itr_nodo_id != null: 
		if nodo_novo != null and itr_nodo_id == nodo_novo.get_instance_id():
			# Caso nodo_novo == null, então a animação é para a remoção
			itr_nodo_id = lista.get_nodo_anterior_id(itr_nodo_id)
		
		var new_label = $LabelPosNodos.duplicate()
		var itr_nodo_instance = instance_from_id(itr_nodo_id)
		new_label.name = 'label'
		
		if i == 1:
			colocar_no_grupo = true
			new_label.text = 'pos_do_anterior\n=\n' + str(i)
		else:
			new_label.text = str(i)
		
		if colocar_no_grupo:	# Grupo é usado para mover todos os nodos
								#+ anteriores ao clicado simultaneamente.
			itr_nodo_instance.add_to_group('nodos_anteriores_ao_clicado')
		
			
		itr_nodo_instance.add_child(new_label)
		new_label.add_to_group('pos_dos_nodos_group')
		new_label.set_owner(itr_nodo_instance)
		
		if itr_nodo_id == lista.get_nulo_id():
			# A scale do Nulo é diferente da scale dos nodos. A scale de um pai 
			# afeta a translação dos filhos. Assim, 
			new_label.scale = new_label.scale / itr_nodo_instance.scale
			new_label.position = Vector2(-20, -GRID_SIZE.y * 5) / itr_nodo_instance.scale
			
			itr_nodo_id = lista.get_ultimo_nodo_id()
		else:
			new_label.position = Vector2(-20, -GRID_SIZE.y * 5)
			
			itr_nodo_id = lista.get_nodo_anterior_id(itr_nodo_id)

		new_label.set_modulate(Color(1, 1, 1, 0))
		new_label.visible = true
		anim_esmaecer(new_label, true)
		i += 1

func anim_cam_focar_objeto(objeto, modo : String = 'supetao'):
	if modo == 'suave':
		await get_tree().create_tween().tween_property($Camera2D, "position", 
									objeto.position, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	elif modo == 'supetao':
		await AudioListaLigada.play_sfx('cam_supetao')
		await get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC).tween_property(
			$Camera2D, "zoom", Vector2(0.9, 0.9), 
			ANIM_ANIMACAO_DURACAO).finished
			
		await AudioListaLigada.play_sfx('cam_supetao')
		await get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC).tween_property(
			$Camera2D, "position", 
			objeto.position, 
			ANIM_ANIMACAO_DURACAO).finished
			
		await AudioListaLigada.play_sfx('cam_supetao')
		await get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC).tween_property($Camera2D, "zoom", Vector2(1, 1), 
											ANIM_ANIMACAO_DURACAO).finished

func anim_mover_cam(posicao : Vector2):
	get_tree().create_tween().tween_property(
		$Camera2D, 'position', 
		posicao, 0.2
	).set_trans(Tween.TRANS_CIRC)
	
func anim_ptr_surgir(o_ponteiro, posicao : Vector2, label : String):
	o_ponteiro.position = posicao
	o_ponteiro.scale = Vector2(0.2, 0.2)
	o_ponteiro.set_label_text(label)
	if !o_ponteiro.is_inside_tree():
		add_child(o_ponteiro)
	await AudioListaLigada.play_sfx('surgir')
	await get_tree().create_tween().tween_property(o_ponteiro, "scale",
													Vector2(1.5, 1.5), 
													ANIM_ANIMACAO_DURACAO * fator_velocidade_anim / 2). \
													finished

	
func anim_ptr_apontar(ptr, posicao, rotacao, global_position = false):
	var tween = get_tree().create_tween().set_parallel()
	if global_position:
		tween.tween_property(ptr, "global_position", posicao, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim / 2). \
			set_trans(Tween.TRANS_CUBIC)
	else:
		tween.tween_property(ptr, "position", posicao, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim / 2). \
							set_trans(Tween.TRANS_CUBIC)
	await tween.tween_property(ptr, "rotation", deg_to_rad(rotacao), 
								ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).set_trans(
									Tween.TRANS_ELASTIC).finished
	await AudioListaLigada.play_sfx('ptr_mv')

func anim_itr_rect_nodo_centralizado():
	var rect_nodo_centralizado = $RectNodo.duplicate()
	rect_nodo_centralizado.name = 'RectNodoCentralizado'
	var primeiro_nodo_da_lista = instance_from_id(lista.get_primeiro_nodo_id())
	rect_nodo_centralizado.position.x = primeiro_nodo_da_lista. \
										position.x - GRID_SIZE.x * 2
	add_child(rect_nodo_centralizado)
	
	var pos_label = $LabelPosNodos.duplicate()
	pos_label.name = 'PosLabel'
	rect_nodo_centralizado.add_child(pos_label)
	pos_label.global_position = primeiro_nodo_da_lista.global_position + Vector2(
																-20, 
																-GRID_SIZE.y * 7) 
	pos_label.text = 'pos\n=\n'
	rect_nodo_centralizado.set_modulate(Color(1, 1, 1, 0))
	rect_nodo_centralizado.visible = true
	anim_esmaecer(rect_nodo_centralizado, true)
	pos_label.set_owner(rect_nodo_centralizado)
	pos_label.set_modulate(Color(1, 1, 1, 0))
	pos_label.visible = true
	anim_esmaecer(pos_label, true)
	
	return [rect_nodo_centralizado, pos_label]

func anim_itr_rects_e_labels_desaparecendo(rect_nodo, rect_nodo_centralizado):
	anim_esmaecer(rect_nodo)
	anim_esmaecer(rect_nodo_centralizado)
	rect_nodo.visible = false
	rect_nodo_centralizado.visible = false
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	get_tree().call_group('pos_dos_nodos_group', 'free')
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)

func anim_itr_mover_anteriores(nodo_anterior_id, ponteiro_anterior, ptr_lista_copia,
								sentido : String):
	var sentido_sinal : int
	if sentido == 'esq':
		sentido_sinal = -1
	elif sentido == 'dir':
		sentido_sinal = +1
	get_tree().create_tween().tween_property(
		ptr_lista_copia, 'position', 
		ptr_lista_copia.position + sentido_sinal 
		* Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	get_tree().create_tween().set_parallel().tween_property(
		ponteiro_anterior, 'position', 
		ponteiro_anterior.position + sentido_sinal 
		* Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim )

	var para_mover = get_tree().get_nodes_in_group('nodos_anteriores_ao_clicado')
	for item in para_mover:
		get_tree().create_tween().tween_property(
			item, 'position', 
			item.position + sentido_sinal * Vector2(GRID_SIZE.x * 8, 0),
			0.1
		).set_trans(Tween.TRANS_CUBIC)
					
func anim_itr_comportar_em_corrente(nodo_novo, ponteiro_anterior, apontar_para):
	var nodo_novo_ptr = nodo_novo.get_ponteiro_scene()
	var move_tudo_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC). \
		set_parallel()
	move_tudo_tween.tween_property(nodo_novo, "position", apontar_para.position
								- Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	move_tudo_tween.tween_property(nodo_novo_ptr, "rotation", 0, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	move_tudo_tween.tween_property(nodo_novo_ptr, "position", 
								Vector2(GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)

	move_tudo_tween.tween_property(ponteiro_anterior, "global_position", 
									apontar_para.position 
									- Vector2(GRID_SIZE.x * 12, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	
func anim_itr_acompanhar_camera(rect_nodo_centralizado, prox_nodo_centralizado, 
								ponteiro_anterior, nodo_novo = null):
	var acompanhar_camera_tween = get_tree().create_tween().set_parallel()
	acompanhar_camera_tween.tween_property(
		rect_nodo_centralizado, "position",
		Vector2(prox_nodo_centralizado.position.x - GRID_SIZE.x * 2, 
				rect_nodo_centralizado.position.y)
		, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	acompanhar_camera_tween.tween_property(
		$Camera2D, "position",
		Vector2(prox_nodo_centralizado.position)
		, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	acompanhar_camera_tween.tween_property(
		ponteiro_anterior, "position", 
		ponteiro_anterior.position + Vector2(GRID_SIZE.x * 8, 0)
		, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim)
	if nodo_novo:
		await acompanhar_camera_tween.tween_property(
			nodo_novo, "position",
			nodo_novo.position + Vector2(GRID_SIZE.x * 8, 0)
			, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
		
func anim_bloco_codigo_highlight_str(bloco_codigo, stri_e_ocorrencia = null):
	if stri_e_ocorrencia:
		await bloco_codigo.highlight_str(stri_e_ocorrencia[0], stri_e_ocorrencia[1])
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)

func anim_itr_no_meio_pos_dif_zero(nodo_clicado_id, bloco_codigo,
									ponteiro_anterior, insercao : bool, rect_nodo,
									ponteiro_aux = null, nodo_novo = null):
	if insercao:
		rect_nodo.set_modulate(Color(1, 1, 1, 0))
		rect_nodo.visible = true
		anim_esmaecer(rect_nodo, true)
		anim_itr_num_pos_nodos_rev(nodo_clicado_id, nodo_novo)
		## Animação: nodo novo indo para a esquerda da tela
		await get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC). \
			tween_property(nodo_novo, "position", 
							$Camera2D.position 
							- Vector2(((NUMBER_OF_GRIDS.x / 2) - 4)
										* GRID_SIZE.x, 
										((NUMBER_OF_GRIDS.y / 2) - 2) 
										* GRID_SIZE.y
							), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished				
		await anim_bloco_codigo_highlight_str(
			bloco_codigo, 
			['const int pos_do_anterior = 1', 1])
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
									['Nodo *aux = lista;', 1])
		await anim_ptr_surgir(
			ponteiro_aux,
			$Camera2D.position + POS_CANTO_TELA, 'aux')
	
		await anim_ptr_apontar(ponteiro_aux, instance_from_id(
								lista.get_primeiro_nodo_id()
							).position + Vector2(
								0, GRID_SIZE.y * 4), -90)
	else:
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
									['Nodo *aux = lista;', 1])
		await anim_ptr_surgir(ponteiro_aux,
			$Camera2D.position + POS_CANTO_TELA, 'aux')
		await anim_ptr_apontar(ponteiro_aux, instance_from_id(
									lista.get_primeiro_nodo_id()
								).position + Vector2(
									0, GRID_SIZE.y * 4), -90)	
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
											['if(pos == 0)', 1])
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
											['else', 1])
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		
		rect_nodo.set_modulate(Color(1, 1, 1, 0))
		rect_nodo.visible = true
		anim_esmaecer(rect_nodo, true)
		anim_itr_num_pos_nodos_rev(nodo_clicado_id, nodo_novo)
		
		await anim_bloco_codigo_highlight_str(
			bloco_codigo, 
			['const int pos_do_anterior = 1;', 1])
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['Nodo *anterior;', 1])
	
	## Animação ponteiro anterior surgindo
	await anim_ptr_surgir(ponteiro_anterior,
		$Camera2D.position + POS_CANTO_TELA, 'anterior')
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	ponteiro_anterior.play_anim('girar_em_torno_de_si_mesmo')	

func anim_inserir_itr_no_meio_pos_igual_pos_anterior(rect_nodo, 
													rect_nodo_centralizado,
													bloco_codigo,
													nodo_clicado_id,
													nodo_centralizado_id,
													ponteiro_anterior,
													ponteiro_aux, ptr_lista_copia,
													nodo_novo, nodo_anterior):
	var nodo_clicado = instance_from_id(nodo_clicado_id)
	var nodo_centralizado = instance_from_id(nodo_centralizado_id)
	
	await anim_itr_no_meio_preparar_aux_e_anterior(rect_nodo, rect_nodo_centralizado,
													bloco_codigo, nodo_clicado, 
													nodo_centralizado, 
													ponteiro_anterior,
													ponteiro_aux)
	
	## Animação: fazer nodo aproximar-se da posição desejada
	await get_tree().create_tween().tween_property(
		nodo_novo, "position", nodo_clicado.position - Vector2(0, GRID_SIZE.y * 7)
		, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
							['anterior->prox = novo;', 1])

	## Animação: mover os anteriores para a esquerda
	await anim_itr_mover_anteriores(nodo_anterior.get_instance_id(), ponteiro_anterior,
									ptr_lista_copia, 'esq')
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	var nodo_anterior_ptr = nodo_anterior.get_ponteiro_scene()
	## Animação: fazer o ponteiro na horizontal apontar
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	await AudioListaLigada.play_sfx('ptr_mv')
	await get_tree().create_tween().tween_property(
		nodo_anterior_ptr, "global_position", nodo_novo.position - Vector2(
			GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
			
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
			
	var nodo_novo_ptr = nodo_novo.get_ponteiro_scene()
	nodo_novo_ptr.stop_anim()
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
							['novo->prox = aux;', 1])
	
	## Animação: fazer ponteiro do nodo apontar
	await anim_ptr_apontar(nodo_novo_ptr,
							Vector2(0, GRID_SIZE.y * 4), 
							90)
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		
	## Animação: comportar na corrente o nodo, seu ponteiro, e o ponteiro na horizontal
	await anim_itr_comportar_em_corrente(nodo_novo, nodo_anterior_ptr,
											nodo_clicado) 
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['return lista;', 2])
	
func anim_itr_no_meio_pos_dif_pos_anterior(bloco_codigo, ponteiro_aux,
											rect_nodo_centralizado, 
											prox_nodo_centralizado,
											ponteiro_anterior, nodo_novo = null):
	await anim_bloco_codigo_highlight_str(bloco_codigo, null)

	await anim_bloco_codigo_highlight_str(bloco_codigo, 
				['else', 2])
	

	await anim_bloco_codigo_highlight_str(bloco_codigo, 
					['aux = aux->prox;', 2])
					
	## Animação: fazer ponteiro apontar (ponteiro_aux)
	await anim_ptr_apontar(ponteiro_aux,  
					ponteiro_aux.position + Vector2(GRID_SIZE.x * 8, 0)
	 				, rad_to_deg(ponteiro_aux.rotation))
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
				['for(pos; pos > 0; pos--)', 1])
	await AudioListaLigada.play_sfx('passo_iter')
	await anim_itr_acompanhar_camera(rect_nodo_centralizado,
									prox_nodo_centralizado,
									ponteiro_anterior,
									nodo_novo)

func anim_intervalo(tempo):
	await get_tree().create_tween().tween_interval(tempo).finished

func anim_itr_no_meio_preparar_aux_e_anterior(rect_nodo, rect_nodo_centralizado,
												bloco_codigo, nodo_clicado,
												nodo_centralizado,
												ponteiro_anterior, ponteiro_aux):
	AudioListaLigada.play_sfx('passo_iter_ult')
	
	await anim_itr_rects_e_labels_desaparecendo(rect_nodo, 
											rect_nodo_centralizado)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['anterior = aux;', 1])
	
	ponteiro_anterior.stop_anim()
	
	## Animação: fazer ponteiro apontar (ponteiro_anterior)
	await anim_ptr_apontar(ponteiro_anterior, 
							nodo_centralizado.position - Vector2(
								0, GRID_SIZE.y * 4),
							90)

	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['aux = aux->prox;', 1])
	
	## Animação: fazer ponteiro apontar (ponteiro_aux)
	await anim_ptr_apontar(
		ponteiro_aux, 
		ponteiro_aux.position + Vector2(GRID_SIZE.x * 8, 0),
		rad_to_deg(ponteiro_aux.rotation))
								
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
func anim_itr_return(ponteiro_aux, ponteiro_anterior, bloco_codigo):
	if ponteiro_aux:
		await AudioListaLigada.play_sfx('esmaecer')
		await anim_esmaecer(ponteiro_aux)
	if ponteiro_anterior:
		await AudioListaLigada.play_sfx('esmaecer')
		await anim_esmaecer(ponteiro_anterior)

func anim_rec_return(rec_retan, ptr_lista_copia, fila_cor, pilha_cor, bloco_codigo,
					obj_chamada_anterior, eh_insercao : bool, 
					param_recursivos = null):
	rec_retan.color.a8 = 255
	rec_retan.visible = true
	var cor_chamada_anterior = Utilidades.rec_get_cor_saindo(pilha_cor)
	var cor_retorno = rec_retan.color
	var ptr_chamada_anterior
	var fator_distancia : int
	var rect_pos : Vector2
	var sfx_ptr_lista : String 
	if obj_chamada_anterior == ponteiro:
		ptr_chamada_anterior = ponteiro
		rect_pos = obj_chamada_anterior.position - 2 * GRID_SIZE
		fator_distancia = 1
		sfx_ptr_lista = 'Lista_recebe'
	else:
		ptr_chamada_anterior = obj_chamada_anterior.get_ponteiro_scene()
		rect_pos = obj_chamada_anterior.position + DISTAN_PTR_NODO - 2 * GRID_SIZE
		fator_distancia = 2
		sfx_ptr_lista = 'lista_recebe'
		
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['return lista;', 2])
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await get_tree().create_tween().tween_property(
		rec_retan, 'color:a8', 0, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).finished
	rec_retan.visible = false
	
	await AudioListaLigada.play_sfx('sai_rec')
	
	get_tree().create_tween().set_parallel().tween_method(
		parallax_bg.set_cor, parallax_bg.get_cor(), 
		Color(cor_chamada_anterior), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	)
	

	get_tree().create_tween().tween_property(
		ptr_lista_copia, 'self_modulate', cor_retorno, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).finished
	await AudioListaLigada.play_sfx('prox_recebe')
	
	await get_tree().create_tween().tween_property(
		ptr_lista_copia, 'scale', Vector2(2, 2), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).from_current().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).finished
	
	await get_tree().create_tween().set_parallel(false).tween_property(
		ptr_lista_copia, 'scale', Vector2(1.5, 1.5), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim/4
	).from_current().set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT).finished
	
	# Se param_recursivos == null, então é um return de função iterativa
	if param_recursivos != null:
		await get_tree().create_tween().tween_property(
			$Camera2D, 'position:x', $Camera2D.position.x - NODO_COMP_X, 
			ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
		).finished
		
		var label_pos = param_recursivos[0]
		var label_pos_idx = param_recursivos[1]
		label_pos.text = 'pos = ' + str(label_pos_idx)
		if obj_chamada_anterior != ponteiro:
			bloco_codigo.scroll_to_line(0)
			if eh_insercao:
				await anim_bloco_codigo_highlight_str(
					bloco_codigo, 
					['lista->prox = inserir_pos_rec(lista->prox, pos - 1, x);', 1])
			else:
				await anim_bloco_codigo_highlight_str(
					bloco_codigo, 
					['lista->prox = remover_pos_rec(lista->prox, pos - 1);', 1])
			await anim_intervalo(2 * ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		else:
			await anim_esmaecer(label_pos)
	else:
		await anim_cam_focar_objeto(ptr_lista_copia, 'suave')
		await anim_intervalo(ANIM_INTERVALO_DURACAO)

	obj_chamada_anterior.position.x = ptr_lista_copia.position.x -  \
		fator_distancia*NODO_COMP_X
	
	if obj_chamada_anterior == ponteiro:
		ponteiro.set_play_audio(true)
	get_tree().create_tween().set_parallel(true).tween_property(
		obj_chamada_anterior, 'visible', true, 1e-9)
	await get_tree().create_tween().tween_property(
		obj_chamada_anterior, 'modulate', 
		Color(1, 1, 1, 1), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).from(Color(1,1,1,0)).finished

	await AudioListaLigada.play_sfx(sfx_ptr_lista)
	get_tree().create_tween().set_parallel().tween_property(
		ptr_chamada_anterior, 'scale', Vector2(2, 2), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).from_current().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	get_tree().create_tween().tween_property(
		ptr_chamada_anterior, 'self_modulate', cor_retorno, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	)
	
	await get_tree().create_tween().tween_property(
		ptr_lista_copia, 'self_modulate', Color(1,1,1,1), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).finished
	
	await get_tree().create_tween().tween_property(
		ptr_chamada_anterior, 'scale', Vector2(1.5, 1.5), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim/4
	).from_current().set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT).finished
	
	await anim_esmaecer(ptr_lista_copia)
	
	await get_tree().create_tween().tween_property(
		obj_chamada_anterior, 'position:x', 
		ptr_lista_copia.position.x - (fator_distancia - 1)*NODO_COMP_X,
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).finished
	
	await get_tree().create_tween().tween_property(
		ptr_chamada_anterior, 'self_modulate', Color(1,1,1,1), ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).finished
	
	Utilidades.rec_set_rect(rec_retan, rect_pos, cor_chamada_anterior)
	
	if obj_chamada_anterior != ponteiro:
		ptr_lista_copia.position.x = obj_chamada_anterior.position.x - NODO_COMP_X
		ptr_lista_copia.set_modulate(Color(1,1,1,1))
		await get_tree().create_tween().tween_property(
			$Camera2D, 'position:x', $Camera2D.position.x - NODO_COMP_X, 
			ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished

func anim_nodo_ascender(nodo_clicado):
	await get_tree().create_tween().tween_property(
	nodo_clicado, 'position', 
	nodo_clicado.position + Vector2(0, -GRID_SIZE.y * 4), 
	ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).finished
	
func anim_set_novo_nodo_pos(nodo_novo):
	nodo_novo.position = $Camera2D.get_screen_center_position()
	nodo_novo.position.y -= VIEWPORT_SIZE.y / 2 / 1.3

func anim_rec_inicio(pilha_cor : Array, fila_cor : Array, bloco_codigo,
					obj_anterior, rec_rect, ptr_lista_copia):
	var rect_cor = Utilidades.rec_get_cor_entrando(pilha_cor, fila_cor)
	var rect_pos
	var ptr_copia_pos 
	if obj_anterior == ponteiro:
		rect_pos = obj_anterior.position - 2 * GRID_SIZE
		ptr_copia_pos = obj_anterior.position
	else:
		rect_pos = obj_anterior.position + DISTAN_PTR_NODO - 2 * GRID_SIZE
		ptr_copia_pos = obj_anterior.position + DISTAN_PTR_NODO
		
	Utilidades.rec_set_rect(rec_rect, rect_pos , rect_cor)
	
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	await get_tree().create_tween().tween_property(
		obj_anterior, 'position', obj_anterior.position -  DISTAN_PTR_NODO,
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).set_trans(Tween.TRANS_CUBIC).finished
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_surgir(ptr_lista_copia, ptr_copia_pos,
							'lista')
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	rec_rect.visible = true
	rec_rect.color.a8 = 0
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)

	await get_tree().create_tween().tween_property(
		rec_rect, 'color:a8', 255, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).set_trans(Tween.TRANS_CUBIC).finished
	
	await AudioListaLigada.play_sfx('entra_rec')
	await anim_rec_mover_cam(rec_rect, ptr_lista_copia, 1)
	
	parallax_bg.set_cor(rect_cor)
	
	obj_anterior.visible = false
	if obj_anterior == ponteiro:
		ponteiro.set_play_audio(false)

	rec_rect.visible = false
	rec_rect.color.a8 = 0
	
func anim_rec_mover_cam(rect, ptr_lista_copia, sentido : int):
	await get_tree().create_tween().tween_property(
		$Camera2D, 'position:x', 
		(rect.position.x + sentido * rect.get_size().x/2) - 8, ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).finished
	
	
func anim_rec_inserir_no_comeco(nodo_novo, pilha_cor, fila_cor, bloco_codigo,
	rec_rect, ptr_lista_copia, obj_insercao_id, label_pos, label_x_random):
	anim_set_novo_nodo_pos(nodo_novo)
	
	label_pos.text = 'pos = 0'
	label_pos.set_modulate(Color(1, 1, 1, 0))
	label_pos.visible = true

	await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo,
						ponteiro, rec_rect, ptr_lista_copia)
	await anim_x_info(label_x_random)
	await anim_esmaecer(label_pos, true)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		
	await anim_inserir_rec_nodo_novo(nodo_novo, bloco_codigo)
	await anim_inserir_no_inicio(
		nodo_novo, bloco_codigo, obj_insercao_id, ptr_lista_copia
	)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	await nodo_novo.esfera_stop_anim()
	await anim_rec_return(
		rec_rect, ptr_lista_copia, fila_cor, pilha_cor, bloco_codigo,
		ponteiro, true, [label_pos, 0]
	)
	
func anim_rec_inserir_no_meio(nodo_anterior_ao_clic_id, pilha_cor, fila_cor, 
								bloco_codigo, rec_rect, ptr_lista_copia, 
								nodo_novo, nodo_clicado_id, label_pos, label_x_random):
	var nodo_anterior_ao_clic = instance_from_id(
		nodo_anterior_ao_clic_id
	)
	var nodo_anterior_id
	var ultimo_nodo_inserido_id = lista.get_ultimo_nodo_inserido_id()
	# O último nodo inserido na estrutura lista, antes da animação
	# ocorrer, é sempre anterior ao nodo clicado na lista visual.
	
	await anim_rec_percorrer(
		ultimo_nodo_inserido_id, nodo_anterior_id, pilha_cor, fila_cor, 
		bloco_codigo, rec_rect, ptr_lista_copia, true, label_pos, label_x_random)
	
	await get_tree().create_tween().tween_property(
		ptr_lista_copia, 'position', 
		ptr_lista_copia.position - DISTAN_PTR_NODO, 
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).set_trans(Tween.TRANS_CUBIC).finished
	await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo,
							nodo_anterior_ao_clic, rec_rect, 
							ptr_lista_copia)

	anim_set_novo_nodo_pos(nodo_novo)
	await anim_inserir_rec_nodo_novo(nodo_novo, bloco_codigo)
	await anim_inserir_no_inicio(nodo_novo, bloco_codigo, 
								nodo_clicado_id, ptr_lista_copia)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	await nodo_novo.esfera_stop_anim()

	AudioListaLigada.play_mus('rec_ret')
	await anim_rec_retornar_do_meio(ultimo_nodo_inserido_id, rec_rect, 
									ptr_lista_copia, fila_cor, pilha_cor,
									bloco_codigo, true, label_pos)
	
func anim_rec_remover_pos_zero(bloco_codigo, ptr_lista_copia, nodo_clicado_id):
	var ponteiro_aux = ponteiro_scene.instantiate()
	var nodo_clicado = instance_from_id(nodo_clicado_id)
	var nodo_posterior_id = lista.get_nodo_posterior_id(nodo_clicado_id)
	var nodo_posterior : Variant  
	
	if nodo_posterior_id != null:
		nodo_posterior = instance_from_id(nodo_posterior_id)
	else:
		nodo_posterior = $Nulo
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['if(pos == 0)', 1])
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['Nodo *aux = lista;', 1])
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_surgir(
		ponteiro_aux,
		$Camera2D.position + POS_CANTO_TELA + Vector2(0, 4*GRID_SIZE.y) ,
		'aux')
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_apontar(
		ponteiro_aux, nodo_clicado.position + Vector2(0, -4 * GRID_SIZE.y), 
		90)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)

	await anim_bloco_codigo_highlight_str(bloco_codigo, ['lista = lista->prox;', 1])
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_apontar(
		ptr_lista_copia, nodo_posterior.position + Vector2(0, -4 * GRID_SIZE.y),
		90)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_apontar(
		ponteiro_aux, nodo_clicado.position - DISTAN_PTR_NODO, 
		0)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['free(aux);', 1])
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_nodo_ascender(nodo_clicado)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await AudioListaLigada.play_sfx('esmaecer')
	await anim_esmaecer(nodo_clicado)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	ponteiro_aux.play_anim('girar_em_torno_de_si_mesmo')
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_ptr_apontar(ptr_lista_copia, 
							nodo_posterior.position - DISTAN_PTR_NODO, 0)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['return lista;', 2])
	await AudioListaLigada.play_sfx('esmaecer')
	await anim_esmaecer(ponteiro_aux)
	await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
	
func anim_rec_percorrer(nodo_parada_id, nodo_anterior_id,
						pilha_cor, fila_cor, bloco_codigo, rec_rect,
						ptr_lista_copia, eh_insercao : bool, label_pos, label_x_random = null):
	var nodo_anterior
	
	var label_pos_idx = lista.get_nodo_id_idx(nodo_parada_id)
	label_pos.text = 'pos = ' + str(label_pos_idx)
	label_pos.set_modulate(Color(1,1,1,0))
	label_pos.visible = true 
	var nodo_atual_id = lista.get_primeiro_nodo_id()
	while nodo_atual_id != nodo_parada_id:
		nodo_anterior_id = lista.get_nodo_anterior_id(nodo_atual_id)
		if nodo_anterior_id == null:
			await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo,
								ponteiro, rec_rect, 
								ptr_lista_copia)
			await anim_esmaecer(label_pos, true)
			if label_x_random:
				await anim_x_info(label_x_random)
		else:
			nodo_anterior = instance_from_id(nodo_anterior_id)
			await get_tree().create_tween().tween_property(
				ptr_lista_copia, 'position', 
				ptr_lista_copia.position - DISTAN_PTR_NODO, 
				ANIM_ANIMACAO_DURACAO * fator_velocidade_anim
			).set_trans(Tween.TRANS_CUBIC).finished
			await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo,
								nodo_anterior, rec_rect, 
								ptr_lista_copia)
			
		await anim_bloco_codigo_highlight_str(bloco_codigo, ['if(pos == 0)', 1])
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		await anim_bloco_codigo_highlight_str(bloco_codigo, ['else', 1])
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		if eh_insercao:
			await anim_bloco_codigo_highlight_str(bloco_codigo, 
				['lista->prox = inserir_pos_rec(lista->prox, pos - 1, x);', 1])
		else:
			await anim_bloco_codigo_highlight_str(bloco_codigo, 
				['lista->prox = remover_pos_rec(lista->prox, pos - 1);', 1])
		await anim_intervalo(ANIM_INTERVALO_DURACAO * fator_velocidade_anim)
		
		nodo_atual_id = lista.get_nodo_posterior_id(nodo_atual_id)
		label_pos_idx -= 1
		label_pos.text = 'pos = ' + str(label_pos_idx)
	
func anim_rec_retornar_do_meio(nodo_inicial_id, rec_rect, ptr_lista_copia, 
								fila_cor, pilha_cor, bloco_codigo, eh_insercao : bool,
								label_pos):
	var label_pos_idx = 0
	var nodo_anterior
	var nodo_anterior_id = lista.get_nodo_anterior_id(nodo_inicial_id)
	while nodo_anterior_id != null:
		nodo_anterior = instance_from_id(nodo_anterior_id)
		label_pos_idx += 1
		await anim_rec_return(
			rec_rect, ptr_lista_copia, fila_cor, pilha_cor, bloco_codigo,
			nodo_anterior, eh_insercao, [label_pos, label_pos_idx]
		)
		nodo_anterior_id = lista.get_nodo_anterior_id(nodo_anterior_id)

	await anim_rec_return(
		rec_rect, ptr_lista_copia, fila_cor, pilha_cor, bloco_codigo,
		ponteiro, eh_insercao, [label_pos, label_pos_idx]
	)
	
func anim_rec_remover_do_meio(nodo_clicado_id, nodo_anterior_ao_clic_id, pilha_cor,
					 		fila_cor, bloco_codigo, rec_rect, ptr_lista_copia,
							label_pos):
	var nodo_anterior_ao_clic = instance_from_id(nodo_anterior_ao_clic_id)
	var nodo_anterior_id
	
	await anim_rec_percorrer(nodo_clicado_id, nodo_anterior_id,
		pilha_cor, fila_cor, bloco_codigo, rec_rect, ptr_lista_copia, false,
		label_pos, null)
		
	await get_tree().create_tween().tween_property(
		ptr_lista_copia, 'position', 
		ptr_lista_copia.position - DISTAN_PTR_NODO, 
		ANIM_ANIMACAO_DURACAO * fator_velocidade_anim).set_trans(Tween.TRANS_CUBIC).finished
	await anim_rec_inicio(pilha_cor, fila_cor, bloco_codigo,
							nodo_anterior_ao_clic, rec_rect, 
							ptr_lista_copia)
							
	await anim_rec_remover_pos_zero(bloco_codigo, ptr_lista_copia, nodo_clicado_id)
	
	AudioListaLigada.play_mus('rec_ret')
	await anim_rec_retornar_do_meio(nodo_clicado_id, rec_rect,
									ptr_lista_copia, fila_cor, pilha_cor, 
									bloco_codigo, false, label_pos)

