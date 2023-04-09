// ------------------------------------------------------------------------- Module écoute
// Description	: Ce template du module d'écoute "basic" lance simplement les deux autres modules, et attend leurs arrêts avant de s'arrêter
//				  lui-même.
// Balise : aucun
// Import : aucun
fn (shared sv SharedVariable) module_ecoute(){
	lock sv.module_state {
		sv.module_state[Module.ecoute] = ModuleState.running
	}

	// on remplis le tableau des commandes à exécuter
	lock sv {
		for i in 0 .. sv.commandes_list.len {
			sv.execution_commande_list << i
		}
	}

	m_execution := spawn sv.module_execution()
	m_envoie := spawn sv.module_envoie()
	m_execution.wait()
	m_envoie.wait()

	lock sv.module_state {
		sv.module_state[Module.ecoute] = ModuleState.finish
	}
}