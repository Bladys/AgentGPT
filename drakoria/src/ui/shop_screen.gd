extends ScreenBase
## Boutique de démonstration. Chaque offre indique prix, contenu, caractère
## facultatif et état d'achat. Aucun paiement réel n'est possible.

var _status: Label


func build() -> void:
	header(UI.tr_key("shop.title"))
	root.add_child(UI.demo_banner("shop.demo"))
	var body := scroll_body()
	body.add_child(UI.label(UI.tr_key("shop.optional"), 14, UI.INK))
	for p in Purchases.products:
		var card := UI.card()
		var v := UI.vbox(12)
		card.add_child(v)
		v.add_child(UI.label(UI.tr_key(p["name_key"]), 18, UI.INK))
		v.add_child(UI.label(UI.tr_key(p["desc_key"]), 14, UI.INK_SOFT))
		v.add_child(UI.label(UI.tr_key("shop.price", {"price": Purchases.localized_price(p["id"])}), 14, UI.INK))
		var id: String = p["id"]
		if Purchases.owns(id):
			var h := UI.hbox(12)
			var ic := UIIcon.new()
			ic.kind = "check"
			ic.color = UI.GREEN
			h.add_child(ic)
			h.add_child(UI.label(UI.tr_key("shop.owned"), 15, UI.GREEN))
			v.add_child(h)
		else:
			v.add_child(UI.label(UI.tr_key("shop.not_owned"), 13, UI.INK_SOFT))
			v.add_child(UI.button(UI.tr_key("shop.buy"), "shop", "secondary", func(): Purchases.request_purchase(id)))
		body.add_child(card)
	var card := UI.card()
	var v := UI.vbox(12)
	card.add_child(v)
	v.add_child(UI.label(UI.tr_key("shop.hint_title", {"n": Progression.state["hints"]}), 18, UI.INK))
	v.add_child(UI.label(UI.tr_key("shop.hint_explain"), 14, UI.INK_SOFT))
	v.add_child(UI.button(UI.tr_key("hints.watch"), "video", "secondary", func(): Ads.request_rewarded("hint_shop")))
	body.add_child(card)
	_status = UI.label("", 14, UI.INK, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_status)
	body.add_child(UI.button(UI.tr_key("shop.restore"), "", "secondary", func():
		_status.text = UI.tr_key("shop.restored", {"n": Purchases.restore_purchases()})))
	Purchases.purchase_finished.connect(_on_purchase)
	Ads.rewarded_finished.connect(_on_ad)


func _on_purchase(_id: String, success: bool) -> void:
	if success:
		main.call_deferred("refresh")
	else:
		_status.text = UI.tr_key("shop.cancelled")


func _on_ad(placement: String, txn: String, completed: bool) -> void:
	if placement != "hint_shop":
		return
	if completed and Progression.grant(txn, "hints", int(Progression.config["hints"]["rewarded_ad"])):
		main.call_deferred("refresh")
	else:
		_status.text = UI.tr_key("ads.failed")


func on_exit() -> void:
	Purchases.purchase_finished.disconnect(_on_purchase)
	Ads.rewarded_finished.disconnect(_on_ad)
