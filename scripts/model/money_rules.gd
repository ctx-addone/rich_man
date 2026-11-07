class_name RichMoneyRules
extends RefCounted

# Unknown original threshold/comparison: explicit integration profile.
const TEST_PROFILE = {"reaction_threshold":500}
static func begin(g, payer:int, amount:int, receiver:int=-1, source:String="rent") -> bool:
	if g.phase=="finished" or amount<0 or payer<0 or payer>=g.players.size() or receiver>=g.players.size() or receiver< -1 or g.players[payer].bankrupt: return false
	if amount==0: return true
	var event := {"source":source,"attacker":receiver,"queue":[payer],"kind":"money","days":0,"target":-1,"visited":[],"amount":amount,"receiver":receiver}
	if not g.pending_attack.is_empty(): g.pending_attack.events.append(event)
	else:
		event.merge({"return_phase":g.phase,"arrival":false,"events":[]})
		g.pending_attack=event
		g.phase="reaction"
	return true
