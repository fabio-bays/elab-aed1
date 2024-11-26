extends Node

@export var nodo_scene : PackedScene
@export var bloco_codigo_scene : PackedScene
@export var ponteiro_scene : PackedScene

const VIEWPORT_SIZE = Vector2(320, 180)
const GRID_SIZE = Vector2(8, 8)
const NUMBER_OF_GRIDS = Vector2(VIEWPORT_SIZE / GRID_SIZE)
const NODO_COMP_X = 11 * GRID_SIZE.x
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

const ANIM_INTERVALO_DURACAO : float = .1 # em segundos
const ANIM_ANIMACAO_DURACAO : float = .1

var camera_direction = Vector2(0,0)
var modo_animacao_iterativa #-> o jogo começa com qual modo ativado?
var lista

signal inserir_toggled
signal remover_toggled


class Lista:
	var lista : Dictionary
	var nulo_id : int
	
	## Primeiro e último nodo da lista visualmente apenas. No dicionário "lista", 
	## o último objeto é sempre o último a ser inserido.
	var primeiro_nodo_da_lista_id
	var ultimo_nodo_da_lista_id
	
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
		if !self.lista.is_empty():
			self.lista[nodo_novo_id] = {'pos' : null, 'ant' : null}
			
			var nodo_anterior_id 
			if nodo_clicado_id != self.nulo_id:
				nodo_anterior_id = self.lista[nodo_clicado_id]['ant']
				self.lista[nodo_clicado_id]['ant'] = nodo_novo_id
				self.lista[nodo_novo_id]['pos'] = nodo_clicado_id
			else:
				nodo_anterior_id = self.ultimo_nodo_da_lista_id
				self.ultimo_nodo_da_lista_id = nodo_novo_id
				self.lista[nodo_novo_id]['pos'] = null
			
			if nodo_anterior_id != null:
				self.lista[nodo_anterior_id]['pos'] = nodo_novo_id
				self.lista[nodo_novo_id]['ant'] = nodo_anterior_id
			else: 	
				self.primeiro_nodo_da_lista_id = nodo_novo_id 
		else:
			self.lista[nodo_novo_id] = {'pos' : null, 'ant' : null}
			self.primeiro_nodo_da_lista_id = nodo_novo_id
			self.ultimo_nodo_da_lista_id = nodo_novo_id

	func erase_nodo_id(nodo_clicado_id):
		var nodo_anterior_id = self.lista[nodo_clicado_id]['ant']
		var nodo_posterior_id = self.lista[nodo_clicado_id]['pos']
		
		if nodo_anterior_id != null:
			self.lista[nodo_anterior_id]['pos'] = self.lista[nodo_clicado_id]['pos']
		if nodo_posterior_id != null:
			self.lista[nodo_posterior_id]['ant'] = self.lista[nodo_clicado_id]['ant']
		if nodo_clicado_id == self.ultimo_nodo_da_lista_id:
			self.ultimo_nodo_da_lista_id = self._checar_se_null(nodo_anterior_id)
		if nodo_clicado_id == self.primeiro_nodo_da_lista_id:
			self.primeiro_nodo_da_lista_id = self._checar_se_null(nodo_posterior_id)
		self.lista.erase(nodo_clicado_id)
		
	func get_nodo_posterior_id(nodo_atual_id : int):
		return self.lista[nodo_atual_id]['pos']
	func get_nodo_anterior_id(nodo_atual_id : int):
		return self.lista[nodo_atual_id]['ant']
	func get_nulo_id():
		return self.nulo_id
		
	func get_ultimo_nodo_inserido_id():
		return lista.keys()[-1]
			
func _ready():
	$Ponteiro.set_label_text('lista')
	$Nulo.add_user_signal('nulo_clicado', [null, 'acao'])
	$Nulo.connect('nulo_clicado', _on_nodo_ou_nulo_clicado)
	anim_o_comeco()
	lista = Lista.new()
	lista.nulo_id = $Nulo.get_instance_id()

func _process(delta):
	if lista.lista.is_empty(): 
		$Camera2D/Botoes/Remover.button_pressed = false

	if Input.is_anything_pressed():
		if Input.is_action_pressed('ui_left'):
			camera_direction.x = -300
			$Camera2D.position += camera_direction * delta
		elif Input.is_action_pressed('ui_right'):
			camera_direction.x = 300
			$Camera2D.position += camera_direction * delta

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
			set_visibilidade_botoes(false)
			await anim_insercao_nodo()
			inserir_button.set_pressed_no_signal(false)
			set_visibilidade_botoes(true)
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
		
func _on_nodo_ou_nulo_clicado(nodo_clicado_id, acao):
	# Se nulo foi clicado, nodo_clicado_id = nulo_id
	if acao == 1:
		inserir_toggled.emit()
		set_visibilidade_botoes(false)
		inserir_nodo(nodo_clicado_id)
		await anim_insercao_nodo(nodo_clicado_id)
		$Camera2D/Botoes/Inserir.set_pressed_no_signal(false)
		set_visibilidade_botoes(true)
	elif acao == 2:
		if nodo_clicado_id != lista.get_nulo_id():
			$RemoverX.visible = false
			set_visibilidade_botoes(false)
			await anim_remocao_nodo(nodo_clicado_id)
			remover_nodo(nodo_clicado_id)
			$Camera2D/Botoes/Remover.button_pressed = false
			set_visibilidade_botoes(true)

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

		
func inserir_nodo(nodo_clicado_id = null):
	var nodo = nodo_scene.instantiate()
	var nodo_novo_id = nodo.get_instance_id()
	
	lista.push_nodo_id(nodo_novo_id, nodo_clicado_id)
	#if !lista.is_empty():
		#lista[nodo_novo_id] = {'pos' : null, 'ant' : null}
		#
		#var nodo_anterior_id 
		#if nodo_clicado_id != lista.get_nulo_id():
			#nodo_anterior_id = lista[nodo_clicado_id]['ant']
			#lista[nodo_clicado_id]['ant'] = nodo_novo_id
			#lista[nodo_novo_id]['pos'] = nodo_clicado_id
		#else:
			#nodo_anterior_id = ultimo_nodo_da_lista_id
			#ultimo_nodo_da_lista_id = nodo_novo_id
			#lista[nodo_novo_id]['pos'] = null
		#
		#if nodo_anterior_id != null:
			#lista[nodo_anterior_id]['pos'] = nodo_novo_id
			#lista[nodo_novo_id]['ant'] = nodo_anterior_id
		#else: 	
			#primeiro_nodo_da_lista_id = nodo_novo_id 
	#else:
		#lista[nodo_novo_id] = {'pos' : null, 'ant' : null}
		#primeiro_nodo_da_lista_id = nodo_novo_id
		#ultimo_nodo_da_lista_id = nodo_novo_id
	
	connect('inserir_toggled', nodo._on_inserir_toggled)
	connect('remover_toggled', nodo._on_remover_toggled)
	nodo.connect('nodo_clicado', _on_nodo_ou_nulo_clicado)
	nodo.connect('nodo_mouse_pairando', _on_nodo_mouse_pairando)

	
func remover_nodo(nodo_clicado_id):
	#lista.erase_nodo_id(nodo_clicado_id)
	#var nodo_anterior_id = lista[nodo_clicado_id]['ant']
	#var nodo_posterior_id = lista[nodo_clicado_id]['pos']
	#
	#if nodo_anterior_id != null:
		#lista[nodo_anterior_id]['pos'] = lista[nodo_clicado_id]['pos']
	#if nodo_posterior_id != null:
		#lista[nodo_posterior_id]['ant'] = lista[nodo_clicado_id]['ant']
	#
	##while nodo_posterior_id != null:
		##var nodo_posterior = instance_from_id(nodo_posterior_id)
		##nodo_posterior_id = lista[nodo_posterior_id]['pos']
	#if nodo_clicado_id == ultimo_nodo_da_lista_id:
		#ultimo_nodo_da_lista_id = lista[nodo_clicado_id]['ant']
	#lista.erase(nodo_clicado_id)
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
	elif $Camera2D/Botoes/Remover.button_pressed:
		if modo_animacao_iterativa:
			bloco_codigo.display_str = DISPLAY_STRS[1]
			
	$Camera2D.add_child(bloco_codigo)
	return bloco_codigo
	
func remover_bloco_codigo(bloco_codigo):
	$Camera2D.remove_child(bloco_codigo)
	bloco_codigo.free()

func set_visibilidade_botoes(visibilidade : bool):
	var remover_button = $Camera2D/Botoes/Remover
	var inserir_button = $Camera2D/Botoes/Inserir
	
	remover_button.visible = visibilidade
	inserir_button.visible = visibilidade
	
func anim_o_comeco():
	var scene_tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO)
	scene_tween.tween_property($Nulo, "scale", Vector2(1.5,1.5), 1).from(Vector2(0,0))
	$Nulo.play()
	$Ponteiro.play()
	scene_tween.tween_property($Ponteiro, "visible", true, 1e-9).from(false)
	scene_tween.tween_property($Ponteiro, "scale", Vector2(1.5, 1.5), 0.5).from(
		Vector2(0.2,0.2))
	
func anim_inserir_itr_nodo_novo(nodo, bloco_codigo):
		anim_bloco_codigo_highlight_str(bloco_codigo, 
										['Nodo *novo = malloc(sizeof(Nodo));', 1])
		
		await get_tree().create_tween().tween_property(
		nodo, "scale", Vector2(1, 1), ANIM_ANIMACAO_DURACAO / 2).from(Vector2(0.3,0.3)).finished
		
		await anim_intervalo(ANIM_INTERVALO_DURACAO * 2)
		
		await anim_bloco_codigo_highlight_str(bloco_codigo, 
			['novo->info = x;', 1])
		
		await nodo.anim_info_esmaecer().animation_finished	#padronizar? -> ao invés de chamar
															#+ um método da cena, extrair o objeto
															#+ da cena e aplicar o tweener?
		
		await anim_intervalo(ANIM_INTERVALO_DURACAO)
		
		await anim_bloco_codigo_highlight_str(bloco_codigo, 
											['if(lista == NULL || pos == 0)', 1])
	
func anim_inserir_itr_no_inicio(nodo, bloco_codigo, apontar_para_id): 
	var apontar_para = instance_from_id(apontar_para_id)
	var nodo_ponteiro = nodo.get_ponteiro_scene()
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	bloco_codigo.highlight_str('novo->prox = lista;')
	## Animação: fazer nodo aproximar-se da posição desejada
	await get_tree().create_tween().tween_property(nodo, "position", 
													apontar_para.position
													- Vector2(
														0, GRID_SIZE.y
														* 7), ANIM_ANIMACAO_DURACAO).finished
	nodo_ponteiro.stop_anim()
	## Animação: fazer ponteiro do nodo apontar
	await anim_ptr_apontar(nodo_ponteiro,
							Vector2(0, GRID_SIZE.y * 4), 
							90)
	
	## Animação: fazer o ponteiro na horizontal apontar
	bloco_codigo.highlight_str('lista = novo;')
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	await get_tree().create_tween().tween_property(
		$Ponteiro, "position", nodo.position - Vector2(
			GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO).finished
	
	## Animação: comportar na corrente o nodo, seu ponteiro, e o ponteiro na horizontal
	var move_tudo_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC). \
		set_parallel()
	move_tudo_tween.tween_property(nodo, "position", apontar_para.position
								- Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO)
	move_tudo_tween.tween_property(nodo_ponteiro, "rotation", 0, ANIM_ANIMACAO_DURACAO)
	move_tudo_tween.tween_property(nodo_ponteiro, "position", 
								Vector2(GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO)

	move_tudo_tween.tween_property($Ponteiro, "global_position", apontar_para.position
								- Vector2(GRID_SIZE.x * 12, 0), ANIM_ANIMACAO_DURACAO)

func anim_inserir_itr_no_meio(nodo_novo, bloco_codigo, nodo_clicado_id, nodo_anterior_id):
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['else', 1])

	var nodo_anterior = instance_from_id(nodo_anterior_id)
	var rect_nodo = $RectNodo
	rect_nodo.position.x = nodo_anterior.position.x \
								- GRID_SIZE.x * 2
	rect_nodo.visible = true
	
	var ponteiro_aux = ponteiro_scene.instantiate()
	var ponteiro_anterior = ponteiro_scene.instantiate()
	
	await anim_itr_no_meio_pos_dif_zero(nodo_clicado_id, bloco_codigo,
										ponteiro_anterior, true, ponteiro_aux,
										nodo_novo)
	
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
				ponteiro_aux, nodo_novo,
				nodo_anterior)
			break
		else:
			nodo_centralizado_id = lista.get_nodo_posterior_id(nodo_centralizado_id)
			var prox_nodo_centralizado = instance_from_id(nodo_centralizado_id)
			
			await anim_itr_no_meio_pos_dif_pos_anterior(
				bloco_codigo, ponteiro_aux, rect_nodo_centralizado, 
				prox_nodo_centralizado, ponteiro_anterior, nodo_novo)

	ponteiro_anterior.free()
	ponteiro_aux.free()

func anim_insercao_nodo(nodo_clicado_id = null):
	if modo_animacao_iterativa:
		var nodo_novo = instance_from_id(lista.get_ultimo_nodo_inserido_id()) 
		var bloco_codigo = display_bloco_codigo()
		
		nodo_novo.position = $Camera2D.get_screen_center_position()
		nodo_novo.position.y -= VIEWPORT_SIZE.y / 2 / 1.3
		add_child(nodo_novo)
		
		await anim_inserir_itr_nodo_novo(nodo_novo, bloco_codigo)
		
		if nodo_clicado_id == null:
			await anim_inserir_itr_no_inicio(nodo_novo, bloco_codigo, lista.get_nulo_id())
		else:
			var nodo_anterior_id = lista.get_nodo_anterior_id_anim(nodo_clicado_id)
		
			if nodo_anterior_id == null:
				await anim_inserir_itr_no_inicio(nodo_novo, bloco_codigo, nodo_clicado_id)
			else:
				await anim_inserir_itr_no_meio(nodo_novo, bloco_codigo, nodo_clicado_id,
												nodo_anterior_id)
		#await anim_inserir_itr_return()
		nodo_novo.esfera_stop_anim()
		remover_bloco_codigo(bloco_codigo)
		
		for nodes in get_tree().get_nodes_in_group('nodos_anteriores_ao_clicado'):
			nodes.remove_from_group('nodos_anteriores_ao_clicado')
		
func anim_remocao_nodo(nodo_clicado_id):
	var bloco_codigo = display_bloco_codigo()
	var nodo_anterior_id = lista.get_nodo_anterior_id(nodo_clicado_id)
	var ponteiro_aux : Variant = null
	var ponteiro_anterior : Variant = null
	var resultado : Array
	
	if nodo_anterior_id == null:
		ponteiro_aux = await anim_remover_itr_primeira_pos(bloco_codigo, 
															nodo_clicado_id)
	else:
		resultado = await anim_remover_itr_no_meio(bloco_codigo, nodo_clicado_id)
		ponteiro_aux = resultado[0]
		ponteiro_anterior = resultado[1]
		
	await anim_esmaecer(ponteiro_aux)
	if ponteiro_anterior:
		await anim_esmaecer(ponteiro_anterior)
	
	## Como a remoção no do
	## O primeiro nodo da lista visual agora é o posterior ao atual primeiro nodo 
	## registrado em lista.
	lista.erase_nodo_id(nodo_clicado_id)
	await anim_itr_cam_focar_objeto(instance_from_id(lista.get_primeiro_nodo_id()))
	remover_bloco_codigo(bloco_codigo)
	
	for nodes in get_tree().get_nodes_in_group('nodos_anteriores_ao_clicado'):
		nodes.remove_from_group('nodos_anteriores_ao_clicado')

func anim_remover_itr_primeira_pos(bloco_codigo, nodo_clicado_id):
	var ponteiro_aux = ponteiro_scene.instantiate()
	var nodo_clicado = instance_from_id(nodo_clicado_id)
	var nodo_posterior_id = lista.get_nodo_posterior_id(nodo_clicado_id)
	var nodo_posterior : Variant
	if nodo_posterior_id != null:
		nodo_posterior = instance_from_id(nodo_posterior_id)
	else:
		nodo_posterior = $Nulo
	
	await anim_itr_cam_focar_objeto(instance_from_id(lista.get_primeiro_nodo_id()))
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['Nodo *aux = lista;', 1])
	
	await anim_ptr_surgir(ponteiro_aux, $Camera2D.position + Vector2(
						GRID_SIZE.x * 16, -GRID_SIZE.y * 8) , 'aux')
						
	await anim_ptr_apontar(ponteiro_aux, instance_from_id(
								lista.get_primeiro_nodo_id()
							).position + Vector2(
								0, GRID_SIZE.y * 4), -90)
	
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['if(pos == 0)', 1])
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['lista = lista->prox;', 1])
	
	await anim_ptr_apontar($Ponteiro, 
							nodo_posterior.position + Vector2(0, -GRID_SIZE.y * 4), 90)

	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, ['free(aux)', 1])	
	
	await get_tree().create_tween().tween_property(
		nodo_clicado, 'position', 
		nodo_clicado.position + Vector2(0, -GRID_SIZE.y * 4), 
		ANIM_ANIMACAO_DURACAO).finished

	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	await anim_esmaecer(nodo_clicado)

	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	ponteiro_aux.play_anim('girar_em_torno_de_si_mesmo')

	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	await anim_ptr_apontar($Ponteiro,
						 nodo_posterior.position + Vector2(
							-GRID_SIZE.x * 4, 0), 0)

	await anim_bloco_codigo_highlight_str(bloco_codigo, 
										['return lista;', 2])
										
	return ponteiro_aux
	
func anim_remover_itr_no_meio(bloco_codigo, nodo_clicado_id) -> Array:
	var ponteiro_anterior = ponteiro_scene.instantiate()
	var ponteiro_aux = ponteiro_scene.instantiate()
	var nodo_anterior_id = lista.get_nodo_anterior_id(nodo_clicado_id)
	var nodo_anterior = instance_from_id(nodo_anterior_id)
	var rect_nodo = $RectNodo
	rect_nodo.position.x = nodo_anterior.position.x \
								- GRID_SIZE.x * 2
	rect_nodo.visible = true
	
	await anim_itr_no_meio_pos_dif_zero(nodo_clicado_id, bloco_codigo,
										ponteiro_anterior, false, ponteiro_aux)
		
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
					
			await anim_intervalo(ANIM_INTERVALO_DURACAO)
			
			await anim_bloco_codigo_highlight_str(bloco_codigo, ['free(aux)', 2])	
			
			await get_tree().create_tween().tween_property(
				nodo_clicado, 'position', 
				nodo_clicado.position + Vector2(0, -GRID_SIZE.y * 4), 
				ANIM_ANIMACAO_DURACAO).finished

			await anim_intervalo(ANIM_INTERVALO_DURACAO)
			
			await anim_esmaecer(nodo_clicado)
			
			await anim_intervalo(ANIM_INTERVALO_DURACAO)
			
			ponteiro_aux.play_anim('girar_em_torno_de_si_mesmo')
			
			await anim_ptr_apontar(nodo_anterior_ptr,
								 Vector2(GRID_SIZE.x * 4, 0), 0)
			
			await anim_itr_mover_anteriores(nodo_anterior_id, ponteiro_anterior, 'dir')
			
			break
		else:
			nodo_centralizado_id = lista.get_nodo_posterior_id(nodo_centralizado_id)
			var prox_nodo_centralizado = instance_from_id(nodo_centralizado_id)
			
			await anim_itr_no_meio_pos_dif_pos_anterior(
				bloco_codigo, ponteiro_aux, rect_nodo_centralizado, 
				prox_nodo_centralizado, ponteiro_anterior)
				
			await anim_intervalo(ANIM_INTERVALO_DURACAO)
			
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
							['return lista;', 2])
	
	return [ponteiro_aux, ponteiro_anterior]
		
func anim_esmaecer(objeto):
	await get_tree().create_tween().tween_method(objeto.set_modulate,
												objeto.modulate, Color(1, 1, 1, 0),
												ANIM_ANIMACAO_DURACAO * 2).finished
	
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
			
		new_label.visible = true
		i += 1

func anim_itr_cam_focar_objeto(objeto):
	## Mover a câmera de supetão para trás e fazê-la focar no primeiro nodo
	##+ da lista.
	var transicao_tween = get_tree().create_tween().	\
		set_trans(Tween.TRANS_ELASTIC)
	transicao_tween.tween_property($Camera2D, "zoom", Vector2(0.9, 0.9), ANIM_ANIMACAO_DURACAO)
	transicao_tween.tween_property($Camera2D, "position", 
									objeto.position, ANIM_ANIMACAO_DURACAO)
	await transicao_tween.tween_property($Camera2D, "zoom", Vector2(1, 1), 
										ANIM_ANIMACAO_DURACAO).finished

func anim_ptr_surgir(ponteiro, posicao : Vector2, label : String):
	ponteiro.position = posicao
	ponteiro.scale = Vector2(0.2, 0.2)
	ponteiro.set_label_text(label)
	add_child(ponteiro)
	await get_tree().create_tween().tween_property(ponteiro, "scale",
													Vector2(1.5, 1.5), 
													ANIM_ANIMACAO_DURACAO / 2). \
													finished

	
func anim_ptr_apontar(ponteiro, posicao, rotacao, global_position = false):
	var tween = get_tree().create_tween().set_parallel()
	if global_position:
		tween.tween_property(ponteiro, "global_position", posicao, ANIM_ANIMACAO_DURACAO / 2). \
			set_trans(Tween.TRANS_CUBIC)
	else:
		tween.tween_property(ponteiro, "position", posicao, ANIM_ANIMACAO_DURACAO / 2). \
							set_trans(Tween.TRANS_CUBIC)
	await tween.tween_property(ponteiro, "rotation", deg_to_rad(rotacao), 
								ANIM_ANIMACAO_DURACAO).set_trans(
									Tween.TRANS_ELASTIC).finished

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
	rect_nodo_centralizado.visible = true
	pos_label.set_owner(rect_nodo_centralizado)
	pos_label.visible = true
	
	return [rect_nodo_centralizado, pos_label]

func anim_itr_rects_e_labels_desaparecendo(rect_nodo, rect_nodo_centralizado):
	rect_nodo.visible = false
	rect_nodo_centralizado.visible = false
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	get_tree().call_group('pos_dos_nodos_group', 'free')
	await anim_intervalo(ANIM_INTERVALO_DURACAO)

func anim_itr_mover_anteriores(nodo_anterior_id, ponteiro_anterior, sentido : String):
	var sentido_sinal : int
	if sentido == 'esq':
		sentido_sinal = -1
	elif sentido == 'dir':
		sentido_sinal = +1
	get_tree().create_tween().tween_property(
		$Ponteiro, 'position', 
		$Ponteiro.position + sentido_sinal 
		* Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO)
	get_tree().create_tween().set_parallel().tween_property(
		ponteiro_anterior, 'position', 
		ponteiro_anterior.position + sentido_sinal 
		* Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO )

	var para_mover = get_tree().get_nodes_in_group('nodos_anteriores_ao_clicado')
	for item in para_mover:
		get_tree().create_tween().tween_property(
			item, 'position', 
			item.position + sentido_sinal * Vector2(GRID_SIZE.x * 8, 0),
			0.1
		).set_trans(Tween.TRANS_CUBIC)

		
		
	#get_tree().call_group('nodos_anteriores_ao_clicado', 
					#'anim_mover', GRID_SIZE.x * 8, sentido_sinal)

					
func anim_itr_comportar_em_corrente(nodo_novo, ponteiro_anterior, apontar_para):
	var nodo_novo_ptr = nodo_novo.get_ponteiro_scene()
	var move_tudo_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC). \
		set_parallel()
	move_tudo_tween.tween_property(nodo_novo, "position", apontar_para.position
								- Vector2(GRID_SIZE.x * 8, 0), ANIM_ANIMACAO_DURACAO)
	move_tudo_tween.tween_property(nodo_novo_ptr, "rotation", 0, ANIM_ANIMACAO_DURACAO)
	move_tudo_tween.tween_property(nodo_novo_ptr, "position", 
								Vector2(GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO)

	move_tudo_tween.tween_property(ponteiro_anterior, "global_position", 
									apontar_para.position 
									- Vector2(GRID_SIZE.x * 12, 0), ANIM_ANIMACAO_DURACAO)
	
func anim_itr_acompanhar_camera(rect_nodo_centralizado, prox_nodo_centralizado, 
								ponteiro_anterior, nodo_novo = null):
	var acompanhar_camera_tween = get_tree().create_tween().set_parallel()
	acompanhar_camera_tween.tween_property(
		rect_nodo_centralizado, "position",
		Vector2(prox_nodo_centralizado.position.x - GRID_SIZE.x * 2, 
				rect_nodo_centralizado.position.y)
		, ANIM_ANIMACAO_DURACAO)
	acompanhar_camera_tween.tween_property(
		$Camera2D, "position",
		Vector2(prox_nodo_centralizado.position)
		, ANIM_ANIMACAO_DURACAO)
	acompanhar_camera_tween.tween_property(
		ponteiro_anterior, "position", 
		ponteiro_anterior.position + Vector2(GRID_SIZE.x * 8, 0)
		, ANIM_ANIMACAO_DURACAO)
	if nodo_novo:
		await acompanhar_camera_tween.tween_property(
			nodo_novo, "position",
			nodo_novo.position + Vector2(GRID_SIZE.x * 8, 0)
			, ANIM_ANIMACAO_DURACAO).finished
		
func anim_bloco_codigo_highlight_str(bloco_codigo, stri_e_ocorrencia = null):
	if stri_e_ocorrencia:
		await bloco_codigo.highlight_str(stri_e_ocorrencia[0], stri_e_ocorrencia[1])
		
	await anim_intervalo(4 * ANIM_INTERVALO_DURACAO)

func anim_itr_no_meio_pos_dif_zero(nodo_clicado_id, bloco_codigo,
									ponteiro_anterior, insercao : bool, 
									ponteiro_aux = null, nodo_novo = null):
	anim_itr_num_pos_nodos_rev(nodo_clicado_id, nodo_novo)
	await anim_itr_cam_focar_objeto(instance_from_id(lista.get_primeiro_nodo_id()))

	if insercao:
		## Animação: nodo novo indo para a esquerda da tela
		await get_tree().create_tween().set_trans(Tween.TRANS_ELASTIC). \
			tween_property(nodo_novo, "position", 
							$Camera2D.position 
							- Vector2(((NUMBER_OF_GRIDS.x / 2) - 4)
										* GRID_SIZE.x, 
										((NUMBER_OF_GRIDS.y / 2) - 2) 
										* GRID_SIZE.y
							), ANIM_ANIMACAO_DURACAO).finished				
		await anim_bloco_codigo_highlight_str(
			bloco_codigo, 
			['const int pos_do_anterior = 1', 1])
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
									['Nodo *aux = lista;', 1])
		await anim_ptr_surgir(
			ponteiro_aux,
			$Camera2D.position + Vector2(GRID_SIZE.x * 16, -GRID_SIZE.y * 8), 'aux')
	
		await anim_ptr_apontar(ponteiro_aux, instance_from_id(
								lista.get_primeiro_nodo_id()
							).position + Vector2(
								0, GRID_SIZE.y * 4), -90)
	else:
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
									[		'Nodo *aux = lista;', 1])
		await anim_ptr_surgir(ponteiro_aux,
			$Camera2D.position + Vector2(GRID_SIZE.x * 16, -GRID_SIZE.y * 8), 'aux')
		await anim_ptr_apontar(ponteiro_aux, instance_from_id(
									lista.get_primeiro_nodo_id()
								).position + Vector2(
									0, GRID_SIZE.y * 4), -90)	
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
											['if(pos == 0)', 1])
		await anim_bloco_codigo_highlight_str(bloco_codigo, 	
											['else', 1])
		await anim_bloco_codigo_highlight_str(
			bloco_codigo, 
			['const int pos_do_anterior = 1', 1])

	await anim_bloco_codigo_highlight_str(bloco_codigo, ['Nodo *anterior;', 1])
	
	## Animação ponteiro anterior surgindo
	await anim_ptr_surgir(ponteiro_anterior,
		$Camera2D.position + Vector2(GRID_SIZE.x * 16, -GRID_SIZE.y * 8), 'anterior')
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	ponteiro_anterior.play_anim('girar_em_torno_de_si_mesmo')	

func anim_inserir_itr_no_meio_pos_igual_pos_anterior(rect_nodo, 
													rect_nodo_centralizado,
													bloco_codigo,
													nodo_clicado_id,
													nodo_centralizado_id,
													ponteiro_anterior,
													ponteiro_aux, nodo_novo,
													nodo_anterior):
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
		, ANIM_ANIMACAO_DURACAO).finished
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
							['anterior->prox = novo;', 1])

	## Animação: mover os anteriores para a esquerda
	await anim_itr_mover_anteriores(nodo_anterior.get_instance_id(), ponteiro_anterior, 'esq')
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
	var nodo_anterior_ptr = nodo_anterior.get_ponteiro_scene()
	## Animação: fazer o ponteiro na horizontal apontar
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	await get_tree().create_tween().tween_property(
		nodo_anterior_ptr, "global_position", nodo_novo.position - Vector2(
			GRID_SIZE.x * 4, 0), ANIM_ANIMACAO_DURACAO).finished
			
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
			
	var nodo_novo_ptr = nodo_novo.get_ponteiro_scene()
	nodo_novo_ptr.stop_anim()
	
	await anim_bloco_codigo_highlight_str(bloco_codigo, 
							['novo->prox = aux;', 1])
	
	## Animação: fazer ponteiro do nodo apontar
	await anim_ptr_apontar(nodo_novo_ptr,
							Vector2(0, GRID_SIZE.y * 4), 
							90)
		
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
		
	## Animação: comportar na corrente o nodo, seu ponteiro, e o ponteiro na horizontal
	await anim_itr_comportar_em_corrente(nodo_novo, nodo_anterior_ptr,
											nodo_clicado) 
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
	
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
								
	await anim_intervalo(ANIM_INTERVALO_DURACAO)
