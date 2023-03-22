
//import os
//<import>

enum ResponseState as u8 {
	success		// La commande à réussi
	error		// La commande à échoué
}

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
	state ResponseState
}

struct SharedVariable {
	// ==== variable partagés
	agent_identifier string = "<id-agent>" // de la forme "agent-x" ou x est le numèro de l'agent

    commandes_list []Commande = [
		Commande{command: "echo hello", type_shell: ShellType.cmd, id: "id"},
		Commande{command: "systeminfo", type_shell: ShellType.powershell, id: "id2"},
	]
mut:
	execution_commande_list []Commande
	ip []u8 = [u8(127),0,0,1]
	response_list []Response
	module_state []ModuleState = [ModuleState.unknown, ModuleState.unknown, ModuleState.unknown]
}

fn main(){
	shared shared_variable := SharedVariable{}

	shared_variable.module_ecoute()
	println("[i] - fin d'éxecution")
}

fn dump_shared_variable(sv &SharedVariable){
	println("=======================-[Dump des shared variables]-=======================")
		println("	identifiant de l'agent : ${sv.agent_identifier}")
		for c in sv.commandes_list	{
			println("${c}")
		}
		println(sv.execution_commande_list)
		println("	ip : ${sv.ip}")
		println("	response_list : ${sv.response_list}")
		println("	module state be like : ${sv.module_state}")
}

//code du <module d'écoute>
fn (shared sv SharedVariable) module_ecoute(){
	println("lancement des threads")

	//tableau_module
	m_execution := spawn sv.module_execution()
	m_envoie := spawn sv.module_envoie()
	m_execution.wait()
	m_envoie.wait()
}

// code du <module execution>
fn (shared sv SharedVariable) module_execution() {
	println("Thread module_execution")
		
	lock sv{
		dump_shared_variable(sv)
		sv.module_state[Module.execution] = ModuleState.finish
	}
}

//code du <module envoie>
fn (shared sv SharedVariable) module_envoie() {
	println("Thread module_envoie")

	rlock sv{
		dump_shared_variable(sv)
	}
}