extends Node2D

const VIEWPORT_SIZE = Vector2(320, 180)

@export var color_rect : ColorRect
@export var parallax_layer : ParallaxLayer

func set_cor(cor):
	color_rect.set_color(cor)

func get_cor():
	return color_rect.color
	

