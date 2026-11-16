extends Node
## PurchaseService — interface + implémentation factice.
## « Démonstration — aucun paiement » : rien n'est facturé, aucun revenu n'est
## enregistré. Un achat n'est confirmé qu'après la confirmation du (faux)
## magasin, jamais à partir d'un simple clic sur le bouton.

signal mock_purchase_prompt(product: Dictionary)
signal purchase_finished(product_id: String, success: bool)

var products: Array = []
var auto_result = null
var _pending := ""
var _counter := 0


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/products.json"))
	products = d["products"]


func product(id: String) -> Dictionary:
	for p in products:
		if p["id"] == id:
			return p
	return {}


func localized_price(id: String) -> String:
	## En production : prix localisé fourni par le magasin. Ici : hypothèse de test.
	var p := product(id)
	return "%.2f €" % float(p.get("test_price_eur", 0.0))


func owns(id: String) -> bool:
	return Progression.owns(id)


func request_purchase(id: String) -> void:
	if _pending != "" or product(id).is_empty() or owns(id):
		return
	_pending = id
	if auto_result != null:
		resolve_mock(bool(auto_result))
	else:
		mock_purchase_prompt.emit(product(id))


func resolve_mock(confirmed: bool) -> void:
	if _pending == "":
		return
	var id := _pending
	_pending = ""
	if confirmed:
		_counter += 1
		var txn := "mockstore:%s:%s:%d" % [id, Analytics.session_id, _counter]
		if Progression.record_purchase(txn, id):
			Analytics.track("purchase_confirmed", {"product": id, "txn": txn, "simulated": true, "revenue": 0})
	purchase_finished.emit(id, confirmed)


func restore_purchases() -> int:
	## Le faux magasin n'a pas de serveur : il restitue ce qui est déjà possédé.
	var n: int = Progression.state["owned"].size()
	Analytics.track("purchase_restored", {"count": n, "simulated": true})
	return n
