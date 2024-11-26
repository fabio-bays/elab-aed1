extends Control

var display_str : String
var rich_text_label : RichTextLabel
var primeira_linha_visivel : int = 0
const MAX_LINHAS_VISIVEIS : int = 11 # depende da resolução da caixa de texto
const ANIM_ROLAR_LINHAS_DURACAO : float = .5

func _ready():
	rich_text_label = $PanelContainer/RichTextLabel
	rich_text_label.text = ''
	set_line_numbers()
	rich_text_label.set_text(display_str)

func set_line_numbers():
	var split_str = display_str.split('\n')
	display_str = ''
	
	var  i = 1
	for line in split_str:
		line = str(i) + '. ' + line + '\n'
		split_str[i - 1] = line
		display_str += split_str[i - 1]
		i += 1
	
func highlight_str(stri : String, ocorrencia : int = 1):
	var str_nova = '[color=green]' + stri + '[/color]'
	var texto = rich_text_label.get_parsed_text()
	var texto_anterior = texto
	var num_char_removidos = 0
	var idx : int
	
	for i in range(0, ocorrencia):
		idx = texto.find(stri, 0)
		if i == ocorrencia - 1:
			texto = texto.substr(idx)
			texto_anterior = texto_anterior.erase(idx + num_char_removidos
												, texto.length())
			texto = texto.erase(0, stri.length())
			texto = texto.insert(0, str_nova)
		else:
			texto = texto.substr(idx + 1) # Para evitar loop infinito
			num_char_removidos += idx + 1
			
	rich_text_label.set_text(texto_anterior + texto)
	await check_view_boundaries(rich_text_label.get_character_line(
		num_char_removidos + idx))
	
func scroll_to_line(line : int):
	rich_text_label.scroll_to_line(line)
	
func check_view_boundaries(line : int):
	if line > (MAX_LINHAS_VISIVEIS + primeira_linha_visivel) \
			or (line < primeira_linha_visivel):
		await get_tree().create_tween().tween_method(
			rich_text_label.scroll_to_line, primeira_linha_visivel, line,
			ANIM_ROLAR_LINHAS_DURACAO).finished
		primeira_linha_visivel = line


