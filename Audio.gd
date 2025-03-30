extends Node2D

const mus_idle : AudioStreamWAV = preload("res://assets/musica/Idle2.wav")
const mus_algor : AudioStreamWAV = preload("res://assets/musica/Algoritmo.wav")
const mus_rec_ret : AudioStreamWAV = preload("res://assets/musica/Recursivo_Return.wav")

const sfx_cam_selecao_nodo_A : AudioStreamWAV = preload('res://assets/sfx/Camera-selecao_nodo_A.wav')
const sfx_cam_selecao_nodo_E : AudioStreamWAV = preload("res://assets/sfx/Camera-selecao_nodo_E.wav")
const sfx_cam_supetao_um : AudioStreamWAV = preload('res://assets/sfx/Camera-supetao_1.wav')
const sfx_cam_supetao_dois : AudioStreamWAV = preload('res://assets/sfx/Camera-supetao_2.wav')
const sfx_cam_supetao_tres : AudioStreamWAV = preload('res://assets/sfx/Camera-supetao_3.wav')
const sfx_cam_entr_rec_Csus : AudioStreamWAV = preload("res://assets/sfx/entrada_recursiva_C#.wav")
const sfx_cam_entr_rec_E : AudioStreamWAV = preload("res://assets/sfx/entrada_recursiva_E.wav")
const sfx_cam_entr_rec_Fsus : AudioStreamWAV = preload("res://assets/sfx/entrada_recursiva_F#.wav")
const sfx_cam_entr_rec_Gsus : AudioStreamWAV = preload("res://assets/sfx/entrada_recursiva_G#.wav")
const sfx_cam_saida_rec_Csus : AudioStreamWAV = preload("res://assets/sfx/saida_recursiva_C#.wav")
const sfx_cam_saida_rec_E : AudioStreamWAV = preload("res://assets/sfx/saida_recursiva_E.wav")
const sfx_cam_saida_rec_Fsus : AudioStreamWAV = preload("res://assets/sfx/saida_recursiva_F#.wav")
const sfx_cam_saida_rec_Gsus : AudioStreamWAV = preload("res://assets/sfx/saida_recursiva_G#.wav")
const sfx_cam_passo_iter : AudioStreamWAV = preload("res://assets/sfx/Camera-passo_iterativo.wav")
const sfx_cam_passo_iter_ultimo : AudioStreamWAV = preload("res://assets/sfx/Camera-passo_iterativo_ultimo.wav")

var sfx_cam_supetao : Array = [sfx_cam_supetao_um, sfx_cam_supetao_dois, 
								sfx_cam_supetao_tres]
var sfx_cam_entr_rec : Array = [sfx_cam_entr_rec_Csus, sfx_cam_entr_rec_E, 
								sfx_cam_entr_rec_Fsus, sfx_cam_entr_rec_Gsus]
var sfx_cam_saida_rec : Array = [sfx_cam_saida_rec_Gsus, sfx_cam_saida_rec_Fsus, 
								sfx_cam_saida_rec_E, sfx_cam_saida_rec_Csus]
								
const MUS_VOL_MAX : float = -16.865
var time_inicio
var audio_fonte : AudioStreamPlayer

var audio_peak_left : Array[float]
var audio_peak_right : Array[float]
func _ready():
	time_inicio = Time.get_ticks_usec()

func _process(_delta):
	audio_peak_left.push_back(AudioServer.get_bus_peak_volume_left_db(0,0))
	audio_peak_right.push_back(AudioServer.get_bus_peak_volume_right_db(0,0))

#func esperar_delay_audio():
	#var time_delay = AudioServer.get_time_to_next_mix() + \
						#AudioServer.get_output_latency()
	#var time_atual = Time.get_ticks_usec() - time_inicio
	#time_atual = max(0, time_atual)
	#
	#var time_comeco_loop = time_atual
	#while time_atual < time_comeco_loop + time_delay:
		#time_atual += Time.get_ticks_usec()
	#
	#audio_fonte.play()
	
func prepara_e_toca(mus : AudioStreamPlayer):
	var musicas : Array = [$MusicaIdle, $MusicaAlgor]
	musicas.remove_at(musicas.find(mus))
	
	var musi : AudioStreamPlayer = musicas[0]
	if musi.playing and musi.volume_db > -80:
		await get_tree().create_tween().tween_property(
			musi, 'volume_db', -80, 1
		).finished

	if mus.playing:
		get_tree().create_tween().tween_property(
				mus, 'volume_db', MUS_VOL_MAX, 1
			)
	else:
		mus.volume_db = MUS_VOL_MAX
		mus.play()
	
func play_mus(mus):
	match mus:
		'idle':
			prepara_e_toca($MusicaIdle)
		'algor':
			$MusicaAlgor.set_stream(mus_algor)
			prepara_e_toca($MusicaAlgor)
		'rec_ret':
			$MusicaAlgor.set_stream(mus_rec_ret)
			$MusicaAlgor.play()

func get_sfx_atual(pilha_audios : Array):
	var atual : AudioStreamWAV = pilha_audios.pop_front()
	pilha_audios.push_back(atual)

	return atual
	
func play_sfx(sfx):
	match sfx:
		'cam_supetao':
			$CamSupetao.set_stream(get_sfx_atual(sfx_cam_supetao))
			$CamSupetao.play()
		'user_mv_dir':
			$UserMv.set_stream(sfx_cam_selecao_nodo_A)
			$UserMv.play()
		'user_mv_esq':
			$UserMv.set_stream(sfx_cam_selecao_nodo_E)
			$UserMv.play()
		'passo_iter':
			$PassoIter.set_stream(sfx_cam_passo_iter)
			$PassoIter.play()
		'passo_iter_ult':
			$PassoIter.set_stream(sfx_cam_passo_iter_ultimo)
			$PassoIter.play()
		'entra_rec':
			$EntraRec.set_stream(get_sfx_atual(sfx_cam_entr_rec))
			$EntraRec.play()
		'sai_rec':
			$SaiRec.set_stream(get_sfx_atual(sfx_cam_saida_rec))
			$SaiRec.play()
		'esmaecer':
			$Esmaecer.play()
		'surgir':
			$Surgir.play()
		'ptr_mv':
			$PtrMv.play()
		'prox_recebe':
			$ProxRecebe.play()
		'lista_recebe':
			$listaRecebe.play()
		'Lista_recebe':
			$ListaRecebe.play()

func reset_sfx():
	sfx_cam_entr_rec = [sfx_cam_entr_rec_Csus, sfx_cam_entr_rec_E,
	 					sfx_cam_entr_rec_Fsus, sfx_cam_entr_rec_Gsus]
	sfx_cam_saida_rec = [sfx_cam_saida_rec_Gsus, sfx_cam_saida_rec_Fsus, 
						sfx_cam_saida_rec_E, sfx_cam_saida_rec_Csus]

