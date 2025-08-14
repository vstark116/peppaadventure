extends Node2D

@onready var peppa_node = $Peppa

# Lấy tham chiếu đến các ProgressBar trong StatBarsContainer
@onready var hunger_bar = $UI/StatBarsContainer/HungerBar
@onready var happiness_bar = $UI/StatBarsContainer/HappinessBar
@onready var alertness_bar = $UI/StatBarsContainer/AlertnessBar
@onready var cleanliness_bar = $UI/StatBarsContainer/CleanlinessBar

# THÊM MỚI: THAM CHIẾU CHO HỆ THỐNG NĂNG LƯỢNG
@onready var energy_bar = $UI/EnergyBar
@onready var notification_label = $UI/NotificationLabel
@onready var energy_timer_label = $UI/EnergyTimerLabel

# Lấy tham chiếu đến các Button trong ActionButtonsContainer
@onready var feed_button = $UI/ActionButtonsContainer/FeedButton
@onready var play_button = $UI/ActionButtonsContainer/PlayButton
@onready var bathe_button = $UI/ActionButtonsContainer/BatheButton
@onready var sleep_button = $UI/ActionButtonsContainer/SleepButton

# Lấy tham chiếu đến Node Background (phải là TextureRect)
@onready var background_sprite = $Background

# THÊM THAM CHIẾU ĐẾN ANIMATIONPLAYER
@onready var background_transition_player: AnimationPlayer = $BackgroundTransitionPlayer


#region Hệ thống thời gian trong game
var current_game_time: float = 0.0 # Thời gian hiện tại trong game (giây)
var DAY_LENGTH_SECONDS: float = 180.0 # Độ dài của một ngày trong game (ví dụ: 180 giây = 1 ngày)

# CÁC DÒNG CẦN THAY ĐỔI: Gán trực tiếp giá trị đã tính toán
const DAY_TO_EVENING_THRESHOLD_SECONDS: float = 60.0 # 60 giây đầu là ban ngày
const EVENING_TO_NIGHT_THRESHOLD_SECONDS: float = 120.0 # 60-120 giây là buổi tối (60 giây tiếp theo)


# Resource Paths cho hình nền
const DAY_BACKGROUND_PATH: String = "res://textures/bg.webp" # Hoặc bg.png nếu bạn không dùng webp
const EVENING_BACKGROUND_PATH: String = "res://textures/evening_bg.png"
const NIGHT_BACKGROUND_PATH: String = "res://textures/night_bg.png"
const RAIN_BACKGROUND_PATH: String = "res://textures/rain_bg.png" # Giữ lại path nhưng không dùng

# Tải trước tất cả các Texture vào bộ nhớ
@onready var day_bg_texture: Texture2D = load(DAY_BACKGROUND_PATH)
@onready var evening_bg_texture: Texture2D = load(EVENING_BACKGROUND_PATH)
@onready var night_bg_texture: Texture2D = load(NIGHT_BACKGROUND_PATH)
@onready var rain_bg_texture: Texture2D = load(RAIN_BACKGROUND_PATH) # Vẫn load nhưng không dùng

# Enum để theo dõi trạng thái thời gian trong ngày
enum TimePeriod { DAY, EVENING, NIGHT }
var current_time_period: TimePeriod = TimePeriod.DAY # Khởi tạo ban đầu là ban ngày

# Biến cho hệ thống mưa (giữ lại biến nhưng không có logic kích hoạt)
var is_raining: bool = false
var rain_timer: float = 0.0 # Đếm ngược thời gian mưa
const RAIN_DURATION: float = 30.0 # Mưa kéo dài 20 giây

var rain_check_timer: float = 0.0 # Đếm thời gian để kiểm tra mưa lại
const RAIN_CHANCE_INTERVAL: float = 10.0 # Kiểm tra mưa mỗi 10 giây game
const RAIN_PROBABILITY: float = 0.2 # 10% cơ hội mưa mỗi lần kiểm tra
#endregion

# THÊM MỚI: THAM CHIẾU ĐẾN CÁC NODE ÂM THANH
@onready var bgm_player = $BGMPlayer # Hoặc $BackgroundMusic tùy tên bạn đặt trong scene
@onready var rain_sound_player = $RainSoundPlayer # Tên Node AudioStreamPlayer cho tiếng mưa

# THÊM MỚI: Tham chiếu đến menu Cài đặt và các điều khiển âm lượng
# LƯU Ý QUAN TRỌNG: CẦN KIỂM TRA LẠI ĐƯỜNG DẪN CỦA CÁC NODE NÀY TRONG SCENE CỦA BẠN!
# Click chuột phải vào node trong Scene Tree -> Copy Node Path
@onready var settings_menu = $UI/SettingsMenu
@onready var music_volume_slider = $UI/SettingsMenu/Panel/VBoxContainer/HBoxContainer/MusicVolumeSlider
@onready var music_mute_button = $UI/SettingsMenu/Panel/VBoxContainer/HBoxContainer/MusicMuteButton
@onready var sfx_volume_slider = $UI/SettingsMenu/Panel/VBoxContainer/HBoxContainer2/SfxVolumeSlider # HBoxContainer2 nếu bạn tạo riêng cho SFX
@onready var sfx_mute_button = $UI/SettingsMenu/Panel/VBoxContainer/HBoxContainer2/SfxMuteButton
@onready var settings_close_button = $UI/SettingsMenu/Panel/VBoxContainer/CloseButton

# THAY ĐỔI ĐƯỜNG DẪN CHO NÚT SETTINGS
@onready var settings_button = $UI/ActionButtonsContainer/SettingsButton # Đảm bảo tên này khớp với tên bạn đặt cho nút "Cài Đặt"

#region CÀI ĐẶT ÂM LƯỢNG (Phần này được thêm vào CUỐI SCRIPT main_game.gd)
var music_bus_index: int
var sfx_bus_index: int

func _init():
	# Lấy index của các Audio Bus một lần khi script khởi tạo
	# Đảm bảo tên Bus khớp với tên bạn đã tạo trong tab Audio (Music, SFX)
	music_bus_index = AudioServer.get_bus_index("Music")
	sfx_bus_index = AudioServer.get_bus_index("SFX")
#endregion

# THÊM MỚI: Hệ thống tiền tệ
@onready var money_label = $UI/MoneyLabel # Đảm bảo đường dẫn này đúng với MoneyLabel bạn đã tạo
var current_money: int = 100 # Bắt đầu với 100 tiền ban đầu (có thể thay đổi)

# Tín hiệu để thông báo trạng thái mưa cho Peppa (Giữ lại tín hiệu nhưng không phát)
signal rain_state_changed(is_currently_raining: bool)

#region HỆ THỐNG MUA ĐỒ ĂN
@onready var food_menu_panel = $UI/FoodMenuPanel # Panel chứa menu đồ ăn

# Nút mua đồ ăn (Food Buy Buttons)
@onready var food_spaghetti_buy_button = $UI/FoodMenuPanel/VBoxContainer/SpaghettiRow/BuyButton
@onready var food_seaweed_buy_button = $UI/FoodMenuPanel/VBoxContainer/SeaweedRow/BuyButton
@onready var food_fried_chicken_buy_button = $UI/FoodMenuPanel/VBoxContainer/FriedChickenRow/BuyButton
@onready var food_hamburger_buy_button = $UI/FoodMenuPanel/VBoxContainer/HamburgerRow/BuyButton
@onready var food_pizza_buy_button = $UI/FoodMenuPanel/VBoxContainer/PizzaRow/BuyButton

# Nhãn hiển thị số lượng (Quantity Labels)
@onready var spaghetti_quantity_label = $UI/FoodMenuPanel/VBoxContainer/SpaghettiRow/QuantitySelector/QuantityLabel
@onready var seaweed_quantity_label = $UI/FoodMenuPanel/VBoxContainer/SeaweedRow/QuantitySelector/QuantityLabel
@onready var fried_chicken_quantity_label = $UI/FoodMenuPanel/VBoxContainer/FriedChickenRow/QuantitySelector/QuantityLabel
@onready var hamburger_quantity_label = $UI/FoodMenuPanel/VBoxContainer/HamburgerRow/QuantitySelector/QuantityLabel
@onready var pizza_quantity_label = $UI/FoodMenuPanel/VBoxContainer/PizzaRow/QuantitySelector/QuantityLabel

# Nút cộng (Plus Buttons)
@onready var spaghetti_plus_button = $UI/FoodMenuPanel/VBoxContainer/SpaghettiRow/QuantitySelector/PlusButton
@onready var seaweed_plus_button = $UI/FoodMenuPanel/VBoxContainer/SeaweedRow/QuantitySelector/PlusButton
@onready var fried_chicken_plus_button = $UI/FoodMenuPanel/VBoxContainer/FriedChickenRow/QuantitySelector/PlusButton
@onready var hamburger_plus_button = $UI/FoodMenuPanel/VBoxContainer/HamburgerRow/QuantitySelector/PlusButton
@onready var pizza_plus_button = $UI/FoodMenuPanel/VBoxContainer/PizzaRow/QuantitySelector/PlusButton

# Nút trừ (Minus Buttons)
@onready var spaghetti_minus_button = $UI/FoodMenuPanel/VBoxContainer/SpaghettiRow/QuantitySelector/MinusButton
@onready var seaweed_minus_button = $UI/FoodMenuPanel/VBoxContainer/SeaweedRow/QuantitySelector/MinusButton
@onready var fried_chicken_minus_button = $UI/FoodMenuPanel/VBoxContainer/FriedChickenRow/QuantitySelector/MinusButton
@onready var hamburger_minus_button = $UI/FoodMenuPanel/VBoxContainer/HamburgerRow/QuantitySelector/MinusButton
@onready var pizza_minus_button = $UI/FoodMenuPanel/VBoxContainer/PizzaRow/QuantitySelector/MinusButton

@onready var food_menu_close_button = $UI/FoodMenuPanel/VBoxContainer/CloseButton

# Dữ liệu các món ăn: Tên, giá, phục hồi đói, tăng hạnh phúc
# LƯU Ý: THÊM ID "key" VÀO DỮ LIỆU ĐỒ ĂN ĐỂ DỄ QUẢN LÝ
const FOOD_ITEMS = {
	"spaghetti": {"price": 25, "hunger_restore": 40, "happiness_gain": 10, "id": "spaghetti"},
	"seaweed": {"price": 15, "hunger_restore": 25, "happiness_gain": 5, "id": "seaweed"},
	"fried_chicken": {"price": 40, "hunger_restore": 60, "happiness_gain": 20, "id": "fried_chicken"},
	"hamburger": {"price": 35, "hunger_restore": 55, "happiness_gain": 18, "id": "hamburger"},
	"pizza": {"price": 50, "hunger_restore": 80, "happiness_gain": 25, "id": "pizza"}
}

# Dictionary để lưu trữ số lượng đã chọn cho mỗi món ăn
var food_quantities: Dictionary = {
	"spaghetti": 1,
	"seaweed": 1,
	"fried_chicken": 1,
	"hamburger": 1,
	"pizza": 1
}
#endregion

func _ready():
	randomize() # Đảm bảo hàm randf() hoạt động ngẫu nhiên
	# Kiểm tra xem các Node có được tìm thấy không trước khi kết nối tín hiệu
	if peppa_node == null:
		print("LỖI: Không tìm thấy Node 'Peppa'! Vui lòng kiểm tra lại tên và vị trí trong Scene.")
		get_tree().quit()

	# THÊM MỚI: Kết nối tín hiệu hết năng lượng từ Peppa
	peppa_node.not_enough_energy.connect(_on_peppa_not_enough_energy)
	# THÊM MỚI: Kết nối tín hiệu hành động hoàn thành từ Peppa
	peppa_node.action_completed.connect(_on_peppa_action_completed)

	# Kết nối tín hiệu cho các nút bấm
	if feed_button != null:
		feed_button.pressed.connect(_on_feed_button_pressed) # Giờ đây sẽ mở menu đồ ăn
	else:
		print("LỖI: Không tìm thấy FeedButton tại đường dẫn UI/ActionButtonsContainer/FeedButton!")

	if play_button != null:
		play_button.pressed.connect(_on_play_button_pressed)
	else:
		print("LỖI: Không tìm thấy PlayButton tại đường dẫn UI/ActionButtonsContainer/PlayButton!")

	if bathe_button != null:
		bathe_button.pressed.connect(_on_bathe_button_pressed)
	else:
		print("LỖI: Không tìm thấy BatheButton tại đường dẫn UI/ActionButtonsContainer/BatheButton!")

	if sleep_button != null:
		sleep_button.pressed.connect(_on_sleep_button_pressed)
	else:
		print("LỖI: Không tìm thấy SleepButton tại đường dẫn UI/ActionButtonsContainer/SleepButton!")

	# Đặt nền ban đầu và trạng thái thời gian
	_update_main_background(true) # Gọi hàm này để thiết lập nền ban đầu (không fade)

	# THÊM MỚI: Đặt giá trị tối đa cho thanh năng lượng (một lần)
	if energy_bar != null and peppa_node != null:
		energy_bar.max_value = peppa_node.MAX_ENERGY

	update_ui() # Cập nhật UI lần đầu khi game bắt đầu
	# THÊM MỚI: Cập nhật đồng hồ năng lượng lần đầu
	update_energy_timer_display()

	# THÊM MỚI: Logic âm thanh khởi tạo
	if bgm_player != null and not bgm_player.playing:
		bgm_player.play() # Đảm bảo nhạc nền được phát khi game bắt đầu

	if rain_sound_player != null and rain_sound_player.playing:
		rain_sound_player.stop() # Đảm bảo tiếng mưa không phát khi bắt đầu game

	# THÊM MỚI: Kết nối tín hiệu cho nút mở Settings
	if settings_button != null:
		print("Đã tìm thấy SettingsButton. Đang kết nối tín hiệu...")
		settings_button.pressed.connect(_on_settings_button_pressed)
	else:
		print("LỖI KHỞI TẠO: Không tìm thấy SettingsButton tại đường dẫn UI/ActionButtonsContainer/SettingsButton! (CẦN KIỂM TRA LẠI ĐƯỜNG DẪN)")


	# THÊM MỚI: Kết nối tín hiệu cho các nút và slider trong SettingsMenu
	if settings_close_button != null:
		settings_close_button.pressed.connect(_on_settings_close_button_pressed)
	else:
		print("LỖI KHỞI TẠO: Không tìm thấy settings_close_button! (Kiểm tra SettingsMenu.tscn)")

	if music_volume_slider != null:
		music_volume_slider.value_changed.connect(_on_music_volume_slider_changed)
	else:
		print("LỖI KHỞI TẠO: Không tìm thấy music_volume_slider! (Kiểm tra SettingsMenu.tscn)")

	if music_mute_button != null:
		music_mute_button.pressed.connect(_on_music_mute_button_pressed)
	else:
		print("LỖI KHỞI TẠO: Không tìm thấy music_mute_button! (Kiểm tra SettingsMenu.tscn)")


	if sfx_volume_slider != null:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_slider_changed)
	else:
		print("LỖI KHỞI TẠO: Không tìm thấy sfx_volume_slider! (Kiểm tra SettingsMenu.tscn)")

	if sfx_mute_button != null:
		sfx_mute_button.pressed.connect(_on_sfx_mute_button_pressed)
	else:
		print("LỖI KHỞI TẠO: Không tìm thấy sfx_mute_button! (Kiểm tra SettingsMenu.tscn)")


	# THÊM MỚI: Tải cài đặt âm lượng khi game bắt đầu
	load_volume_settings()

	# THÊM MỚI: Cập nhật hiển thị tiền khi game bắt đầu
	update_money_display()

	# THÊM MỚI: Khởi tạo và kết nối cho menu đồ ăn
	setup_food_menu()


func _process(delta):
	# --- Logic thời gian trong game ---
	current_game_time += delta
	if current_game_time >= DAY_LENGTH_SECONDS:
		current_game_time -= DAY_LENGTH_SECONDS # Đặt lại thời gian về 0 để bắt đầu ngày mới
		print("Bắt đầu một ngày mới! current_game_time: ", current_game_time)
		current_time_period = TimePeriod.DAY # Đảm bảo trạng thái thời gian được reset
		print("Trạng thái chuyển về: DAY")
		_update_main_background() # Cập nhật nền (có fade)

	# Kiểm tra chuyển đổi các giai đoạn thời gian (luôn kiểm tra vì không còn logic mưa ảnh hưởng)
	# Sử dụng match để kiểm soát luồng chuyển đổi trạng thái tốt hơn
	match current_time_period:
		TimePeriod.DAY:
			if current_game_time >= DAY_TO_EVENING_THRESHOLD_SECONDS:
				current_time_period = TimePeriod.EVENING
				print("Trời chuyển sang chiều rồi! --> Set to EVENING")
				_update_main_background() # Cập nhật nền (có fade)
		TimePeriod.EVENING:
			if current_game_time >= EVENING_TO_NIGHT_THRESHOLD_SECONDS:
				current_time_period = TimePeriod.NIGHT
				print("Trời tối rồi! --> Set to NIGHT")
				_update_main_background() # Cập nhật nền (có fade)
		TimePeriod.NIGHT:
			# Không cần kiểm tra gì thêm ở đây.
			# Chuyển đổi về DAY sẽ được xử lý khi current_game_time đạt DAY_LENGTH_SECONDS
			pass

	# --- Logic hệ thống mưa (Đã lược bỏ logic kích hoạt và dừng mưa tự động) ---
	# Nếu is_raining được thiết lập thủ công, thì vẫn có thể dừng.
	if is_raining:
		rain_timer -= delta
		if rain_timer <= 0:
			stop_rain()
	# KHÔNG CÒN LOGIC rain_check_timer ĐỂ KÍCH HOẠT MƯA TỰ ĐỘNG


	update_ui() # Cập nhật UI liên tục mỗi khung hình
	# THÊM MỚI: Cập nhật đồng hồ năng lượng liên tục
	update_energy_timer_display()

# Hàm mới để quản lý việc thay đổi background chính dựa trên thời gian
# Thêm tham số 'no_fade' để kiểm soát việc fade (mặc định là fade)
func _update_main_background(no_fade: bool = false):
	if background_sprite == null:
		print("LỖI: Không tìm thấy Node 'Background' để cập nhật nền!")
		return

	var target_texture: Texture2D = null
	match current_time_period:
		TimePeriod.DAY:
			target_texture = day_bg_texture
		TimePeriod.EVENING:
			target_texture = evening_bg_texture
		TimePeriod.NIGHT:
			target_texture = night_bg_texture

	if target_texture != null:
		if no_fade: # Nếu không fade, gán texture ngay lập tức
			background_sprite.texture = target_texture
		else: # Nếu có fade, dùng AnimationPlayer
			if background_transition_player != null:
				background_transition_player.play("fade_out_in")
				# Thay đổi texture chính xác tại điểm giữa của fade
				var timer = get_tree().create_timer(background_transition_player.get_animation("fade_out_in").length / 2.0)
				timer.timeout.connect(func():
					background_sprite.texture = target_texture
				)
			else: # Fallback nếu AnimationPlayer không tồn tại
				background_sprite.texture = target_texture

# Hàm để bắt đầu mưa (chỉ dùng nếu bạn gọi thủ công)
func start_rain():
	pass # Giữ hàm nhưng không làm gì

# Hàm để kết thúc mưa (chỉ dùng nếu bạn gọi thủ công)
func stop_rain():
	pass # Giữ hàm nhưng không làm gì


func update_ui():
	# Đảm bảo các thanh bar và Peppa node không bị null
	if peppa_node != null:
		if hunger_bar != null: hunger_bar.value = peppa_node.hunger
		if happiness_bar != null: happiness_bar.value = peppa_node.happiness
		if alertness_bar != null: alertness_bar.value = peppa_node.alertness
		if cleanliness_bar != null: cleanliness_bar.value = peppa_node.cleanliness
		# Cập nhật thanh năng lượng
		if energy_bar != null: energy_bar.value = peppa_node.energy
	else:
		print("Cảnh báo: peppa_node bị null khi cập nhật UI.")


# Các hàm xử lý khi nút bấm được nhấn
func _on_feed_button_pressed():
	# KHÔNG GỌI peppa_node.feed() TRỰC TIẾP NỮA. Giờ đây sẽ hiển thị menu đồ ăn.
	show_food_menu()

func _on_play_button_pressed():
	if peppa_node != null:
		peppa_node.play_with()

func _on_bathe_button_pressed():
	if peppa_node != null:
		peppa_node.bathe()

func _on_sleep_button_pressed():
	if peppa_node != null:
		# Nếu đang là ban ngày và Peppa còn tỉnh táo (alertness cao) thì không thể ngủ (hoặc ngủ ít hiệu quả)
		if current_time_period == TimePeriod.DAY and peppa_node.alertness > 20:
			print("Peppa chưa buồn ngủ lắm vào ban ngày.")
			show_notification_message("Peppa chưa buồn ngủ lắm!") # THÊM THÔNG BÁO
			return
		peppa_node.sleep()

#region HÀM XỬ LÝ THÔNG BÁO VÀ ĐẾM NGƯỢC NĂNG LƯỢNG

# Hàm được gọi khi Peppa phát tín hiệu không đủ năng lượng
func _on_peppa_not_enough_energy(required_energy: float, current_energy: float):
	if notification_label != null:
		notification_label.text = "Hết năng lượng rồi! Cần %.1f, hiện có %.1f." % [required_energy, current_energy]
		notification_label.visible = true # Hiển thị thông báo
		print("Thông báo: Hết năng lượng rồi! Cần: %.1f, Hiện có: %.1f" % [required_energy, current_energy])

		# Tạo một timer một lần để ẩn thông báo sau 2 giây
		var timer = get_tree().create_timer(2.0, false) # 2.0 giây, không lặp lại
		timer.timeout.connect(func():
			if notification_label != null:
				notification_label.visible = false # Ẩn thông báo khi hết giờ
				print("Thông báo: Đã ẩn.")
		)
	else:
		print("Cảnh báo: notification_label bị null khi cố gắng hiển thị thông báo.")

# Hàm cập nhật hiển thị đồng hồ đếm ngược năng lượng
func update_energy_timer_display():
	if peppa_node == null or energy_timer_label == null:
		return # Thoát nếu các node cần thiết chưa được thiết lập

	var current_energy = peppa_node.energy
	# THAY ĐỔI: Sử dụng MAX_ENERGY từ peppa_node để tính toán
	var max_energy = peppa_node.MAX_ENERGY
	var regen_rate_per_second = peppa_node.ENERGY_REGEN_RATE_PER_SECOND # Tốc độ hồi phục từ Peppa.gd

	if current_energy >= max_energy:
		energy_timer_label.text = "Đầy đủ!" # Khi năng lượng đầy
	elif regen_rate_per_second <= 0: # Tránh chia cho 0 hoặc hiển thị sai nếu không hồi phục
		energy_timer_label.text = "Không hồi phục"
	else:
		var energy_needed = max_energy - current_energy
		var time_to_full = energy_needed / regen_rate_per_second

		var minutes = floor(time_to_full / 60) # Tính số phút
		var seconds = fmod(time_to_full, 60) # Tính số giây còn lại

		# Định dạng thời gian thành MM:SS và hiển thị, làm tròn giây cho đẹp
		energy_timer_label.text = "%02d:%02d" % [minutes, ceil(seconds)]
#endregion

#region CÀI ĐẶT ÂM LƯỢNG (Phần này được thêm vào CUỐI SCRIPT main_game.gd)

# Các hàm xử lý việc hiển thị/ẩn menu cài đặt
func _on_settings_button_pressed():
	print("Nút 'Cài đặt' đã được nhấn!") # KIỂM TRA: Xem dòng này có xuất hiện trong Output không
	if settings_menu != null:
		print("Đã tìm thấy SettingsMenu. Đang cố gắng hiển thị...")
		settings_menu.visible = true # Hiển thị menu cài đặt
		update_volume_ui() # Cập nhật các giá trị slider và nút mute khi mở menu
	else:
		print("LỖI CHẠY: settings_menu bị null khi nhấn nút! (Kiểm tra đường dẫn @onready và Scene)")

func _on_settings_close_button_pressed():
	print("Nút 'Đóng cài đặt' đã được nhấn!")
	if settings_menu != null:
		settings_menu.visible = false # Ẩn menu cài đặt
		save_volume_settings() # Lưu cài đặt khi đóng menu
	else:
		print("LỖI CHẠY: settings_menu bị null khi nhấn nút Đóng!")

# Hàm xử lý khi thanh trượt âm lượng nhạc nền thay đổi
func _on_music_volume_slider_changed(value: float):
	# print("Music Volume Changed to: ", value) # Có thể bật để gỡ lỗi thêm
	if music_bus_index != -1: # Đảm bảo bus tồn tại
		AudioServer.set_bus_volume_db(music_bus_index, value)
		# Nếu âm lượng được kéo lên từ mức tắt tiếng, bỏ chọn nút mute
		if value > -35.0 and music_mute_button.button_pressed: # -35.0 là ngưỡng bạn có thể điều chỉnh
			music_mute_button.button_pressed = false
		# Nếu âm lượng được kéo xuống mức tắt tiếng, chọn nút mute
		elif value <= -39.0 and not music_mute_button.button_pressed: # -39.0 để đảm bảo nó rất gần -40 (mức tắt tiếng)
			music_mute_button.button_pressed = true

# Hàm xử lý khi nút Tắt/Mở nhạc nền được nhấn
func _on_music_mute_button_pressed():
	print("Nút Tắt/Mở Nhạc Nền đã được nhấn. Trạng thái: ", music_mute_button.button_pressed)
	if music_bus_index != -1:
		if music_mute_button.button_pressed: # Nếu nút đang ở trạng thái 'được nhấn' (chuyển sang tắt tiếng)
			AudioServer.set_bus_volume_db(music_bus_index, -80.0) # Âm lượng cực nhỏ (gần như tắt hẳn)
			music_volume_slider.value = -80.0 # Cập nhật thanh trượt để khớp
		else: # Nếu nút đang ở trạng thái 'không được nhấn' (chuyển sang mở tiếng)
			AudioServer.set_bus_volume_db(music_bus_index, 0.0) # Đặt lại về âm lượng gốc (0 dB)
			music_volume_slider.value = 0.0 # Cập nhật thanh trượt để khớp

# Hàm xử lý khi thanh trượt âm lượng hiệu ứng thay đổi
func _on_sfx_volume_slider_changed(value: float):
	# print("SFX Volume Changed to: ", value) # Có thể bật để gỡ lỗi thêm
	if sfx_bus_index != -1:
		AudioServer.set_bus_volume_db(sfx_bus_index, value)
		if value > -35.0 and sfx_mute_button.button_pressed:
			sfx_mute_button.button_pressed = false
		elif value <= -39.0 and not sfx_mute_button.button_pressed:
			sfx_mute_button.button_pressed = true

# Hàm xử lý khi nút Tắt/Mở hiệu ứng được nhấn
func _on_sfx_mute_button_pressed():
	print("Nút Tắt/Mở Hiệu Ứng đã được nhấn. Trạng thái: ", sfx_mute_button.button_pressed)
	if sfx_bus_index != -1:
		if sfx_mute_button.button_pressed:
			AudioServer.set_bus_volume_db(sfx_bus_index, -80.0)
			sfx_volume_slider.value = -80.0
		else:
			AudioServer.set_bus_volume_db(sfx_bus_index, 0.0)
			sfx_volume_slider.value = 0.0

# Hàm cập nhật UI của menu cài đặt (slider và nút mute)
func update_volume_ui():
	print("Cập nhật UI âm lượng...")
	if music_volume_slider != null and music_bus_index != -1:
		music_volume_slider.value = AudioServer.get_bus_volume_db(music_bus_index)
		# Kiểm tra xem âm lượng có đang ở mức tắt tiếng không
		music_mute_button.button_pressed = (music_volume_slider.value <= -79.0) # Sử dụng -79.0 để khớp với -80.0 khi tắt tiếng
		print("Music slider set to: ", music_volume_slider.value, ", Mute button pressed: ", music_mute_button.button_pressed)

	if sfx_volume_slider != null and sfx_bus_index != -1:
		sfx_volume_slider.value = AudioServer.get_bus_volume_db(sfx_bus_index)
		sfx_mute_button.button_pressed = (sfx_volume_slider.value <= -79.0)
		print("SFX slider set to: ", sfx_volume_slider.value, ", Mute button pressed: ", sfx_mute_button.button_pressed)


# Lưu cài đặt âm lượng vào file
const SAVE_FILE_PATH = "user://game_settings.json" # Sử dụng .json thay vì .tres để dễ đọc/ghi

func save_volume_settings():
	var settings_data = {
		"music_volume": AudioServer.get_bus_volume_db(music_bus_index),
		"sfx_volume": AudioServer.get_bus_volume_db(sfx_bus_index)
	}
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings_data))
		file.close()
		print("Lưu cài đặt âm lượng thành công!")
	else:
		print("Lỗi: Không thể lưu cài đặt âm lượng.")

# Tải cài đặt âm lượng từ file
func load_volume_settings():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var settings_data = JSON.parse_string(content)
			if settings_data is Dictionary:
				if settings_data.has("music_volume") and music_bus_index != -1:
					AudioServer.set_bus_volume_db(music_bus_index, settings_data["music_volume"])
					if music_volume_slider != null: # Cập nhật thanh trượt nếu đã có trong scene
						music_volume_slider.value = settings_data["music_volume"]
				if settings_data.has("sfx_volume") and sfx_bus_index != -1:
					AudioServer.set_bus_volume_db(sfx_bus_index, settings_data["sfx_volume"])
					if sfx_volume_slider != null: # Cập nhật thanh trượt nếu đã có trong scene
						sfx_volume_slider.value = settings_data["sfx_volume"]
				print("Tải cài đặt âm lượng thành công!")
			else:
				print("Lỗi: Dữ liệu cài đặt không hợp lệ.")
		else:
			print("Lỗi: Không thể tải cài đặt âm lượng.")
	else:
		print("Không tìm thấy file cài đặt âm lượng. Sử dụng cài đặt mặc định.")

#endregion

#region Hệ thống tiền tệ (Thêm vào CUỐI SCRIPT main_game.gd)

# Hàm thêm tiền
func add_money(amount: int, action_name: String = ""):
	current_money += amount
	update_money_display()
	var message = "Bạn vừa nhận được " + str(amount) + " tiền!"
	if action_name != "":
		message = "Hoàn thành " + action_name + "! " + message
	show_notification_message(message)
	print("Tổng tiền hiện tại: " + str(current_money))

# Hàm trừ tiền
func spend_money(amount: int) -> bool:
	if current_money >= amount:
		current_money -= amount
		update_money_display()
		show_notification_message("Đã chi " + str(amount) + " tiền.")
		print("Tổng tiền hiện tại: " + str(current_money))
		return true # Mua thành công
	else:
		show_notification_message("Không đủ tiền!")
		print("Không đủ tiền để thực hiện hành động này!")
		return false # Không đủ tiền

# Hàm cập nhật hiển thị tiền trên UI
func update_money_display():
	if money_label != null:
		money_label.text = "Tiền: " + str(current_money)
	else:
		print("Cảnh báo: money_label bị null khi cập nhật hiển thị tiền.")

# Hàm hiển thị thông báo trên màn hình (sử dụng notification_label đã có)
func show_notification_message(message: String):
	if notification_label != null:
		notification_label.text = message
		notification_label.visible = true
		var timer = get_tree().create_timer(2.0, false) # Hiển thị trong 2 giây
		timer.timeout.connect(func():
			if notification_label != null:
				notification_label.visible = false
		)
	else:
		print("Cảnh báo: notification_label bị null khi cố gắng hiển thị thông báo: ", message)

# Hàm được gọi khi Peppa hoàn thành một hành động
func _on_peppa_action_completed(action_name: String):
	var reward_amount = 0 # Khởi tạo mặc định là 0
	match action_name:
		"feed":
			reward_amount = 0 # Cho ăn không nhận tiền (theo logic của bạn)
			print("Peppa đã ăn. Không nhận tiền thưởng.")
		"play":
			reward_amount = 25 # Đổi thành 15 như bạn đã nói trước đó
			add_money(reward_amount, "chơi game")
			print("Peppa đã chơi xong. Nhận tiền thưởng.")
		"bathe":
			reward_amount = 15 # Đổi thành 5 như bạn đã nói trước đó
			add_money(reward_amount, "tắm")
			print("Peppa đã tắm xong. Nhận tiền thưởng.")
		"sleep":
			reward_amount = 5 # Ngủ không cho tiền hoặc ít (theo logic của bạn)
			print("Peppa đã ngủ dậy. Không nhận tiền thưởng.")
		_:
			print("Hành động không xác định hoàn thành: ", action_name)

#endregion

#region HỆ THỐNG MUA ĐỒ ĂN (Tiếp theo sau các region khác)

func setup_food_menu():
	if food_menu_panel != null:
		food_menu_panel.visible = false # Ẩn menu khi game bắt đầu

	# Thiết lập các nút mua và các điều khiển số lượng
	setup_food_item_controls("spaghetti", food_spaghetti_buy_button, spaghetti_plus_button, spaghetti_minus_button, spaghetti_quantity_label)
	setup_food_item_controls("seaweed", food_seaweed_buy_button, seaweed_plus_button, seaweed_minus_button, seaweed_quantity_label)
	setup_food_item_controls("fried_chicken", food_fried_chicken_buy_button, fried_chicken_plus_button, fried_chicken_minus_button, fried_chicken_quantity_label)
	setup_food_item_controls("hamburger", food_hamburger_buy_button, hamburger_plus_button, hamburger_minus_button, hamburger_quantity_label)
	setup_food_item_controls("pizza", food_pizza_buy_button, pizza_plus_button, pizza_minus_button, pizza_quantity_label)

	if food_menu_close_button != null:
		food_menu_close_button.pressed.connect(hide_food_menu)

# Hàm hỗ trợ để thiết lập các nút và nhãn cho từng món ăn
func setup_food_item_controls(item_key: String, buy_button: Button, plus_button: Button, minus_button: Button, quantity_label: Label):
	var item_data = FOOD_ITEMS.get(item_key)
	if item_data == null:
		print("Lỗi: Không tìm thấy dữ liệu cho món ăn: ", item_key)
		return
	
	var item_name = item_key.capitalize().replace("_", " ") # Chuyển "fried_chicken" thành "Fried Chicken"

	if buy_button != null:
		buy_button.text = "%s\n(%d Tiền)" % [item_name, item_data.price]
		buy_button.pressed.connect(func(): _on_food_item_pressed(item_key))
	
	if quantity_label != null:
		quantity_label.text = str(food_quantities[item_key])
		
	if plus_button != null:
		plus_button.pressed.connect(func(): _on_plus_button_pressed(item_key, quantity_label, buy_button))
		
	if minus_button != null:
		minus_button.pressed.connect(func(): _on_minus_button_pressed(item_key, quantity_label, buy_button))

func show_food_menu():
	if food_menu_panel != null:
		food_menu_panel.visible = true
		# Tạm thời vô hiệu hóa các nút hành động chính khi menu mua đồ ăn mở
		set_action_buttons_enabled(false)
		print("Menu đồ ăn đã hiển thị.")

func hide_food_menu():
	if food_menu_panel != null:
		food_menu_panel.visible = false
		# Bật lại các nút hành động chính khi menu mua đồ ăn đóng
		set_action_buttons_enabled(true)
		print("Menu đồ ăn đã ẩn.")

# HÀM MỚI: Xử lý khi bấm nút "+"
func _on_plus_button_pressed(item_key: String, quantity_label: Label, buy_button: Button):
	food_quantities[item_key] += 1
	quantity_label.text = str(food_quantities[item_key])
	update_food_buy_button_text(item_key, buy_button)
	print("Số lượng ", item_key, " tăng lên: ", food_quantities[item_key])

# HÀM MỚI: Xử lý khi bấm nút "-"
func _on_minus_button_pressed(item_key: String, quantity_label: Label, buy_button: Button):
	if food_quantities[item_key] > 1: # Đảm bảo số lượng không nhỏ hơn 1
		food_quantities[item_key] -= 1
		quantity_label.text = str(food_quantities[item_key])
		update_food_buy_button_text(item_key, buy_button)
		print("Số lượng ", item_key, " giảm xuống: ", food_quantities[item_key])

# HÀM MỚI: Cập nhật text của nút mua khi số lượng thay đổi
func update_food_buy_button_text(item_key: String, buy_button: Button):
	var item_data = FOOD_ITEMS.get(item_key)
	if item_data == null: return
	var item_name = item_key.capitalize().replace("_", " ")
	var total_price = item_data.price * food_quantities[item_key]
	if buy_button != null:
		buy_button.text = "%s x%d\n(%d Tiền)" % [item_name, food_quantities[item_key], total_price]

func _on_food_item_pressed(item_key: String):
	var item_data = FOOD_ITEMS.get(item_key)
	if item_data == null:
		print("Lỗi: Không tìm thấy dữ liệu cho món ăn: ", item_key)
		return

	var quantity = food_quantities[item_key]
	var total_price = item_data.price * quantity
	var total_hunger_restore = item_data.hunger_restore * quantity
	var total_happiness_gain = item_data.happiness_gain * quantity

	if spend_money(total_price): # Nếu mua thành công
		if peppa_node != null:
			peppa_node.consume_food(total_hunger_restore, total_happiness_gain) # Gọi hàm mới của Peppa
			show_notification_message("Peppa đã ăn " + item_key + " x" + str(quantity) + "!")
			hide_food_menu() # Đóng menu sau khi mua thành công
			# Reset số lượng về 1 sau khi mua
			food_quantities[item_key] = 1
			# Cập nhật lại nhãn số lượng và nút mua cho món đó
			# LƯU Ý: Cách lấy node này có thể cần điều chỉnh nếu bạn đặt tên khác AppleRow, SpaghettiRow...
			# Dòng này phải khớp chính xác với tên HBoxContainer của bạn cho từng món ăn
			var quantity_label_node = get_node("UI/FoodMenuPanel/VBoxContainer/" + item_key.capitalize() + "Row/QuantitySelector/QuantityLabel")
			var buy_button_node = get_node("UI/FoodMenuPanel/VBoxContainer/" + item_key.capitalize() + "Row/BuyButton")
			if quantity_label_node != null: quantity_label_node.text = str(food_quantities[item_key])
			if buy_button_node != null: update_food_buy_button_text(item_key, buy_button_node)
	else:
		show_notification_message("Không đủ tiền để mua " + item_key + " x" + str(quantity) + "!")


func set_action_buttons_enabled(enabled: bool):
	if feed_button != null: feed_button.disabled = not enabled
	if play_button != null: play_button.disabled = not enabled
	if bathe_button != null: bathe_button.disabled = not enabled
	if sleep_button != null: sleep_button.disabled = not enabled
	if settings_button != null: settings_button.disabled = not enabled # Vô hiệu hóa cả nút cài đặt

#endregion
