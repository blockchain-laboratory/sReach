import React from 'react';
import AppViews from './views/AppViews';
import DeployerViews from './views/DeployerViews';
import AttacherViews from './views/AttacherViews';
import {renderDOM, renderView} from './views/render';
import './index.css';
import * as backend from './build/index.main.mjs';
import { loadStdlib } from '@reach-sh/stdlib';
const reach = loadStdlib(process.env);

const handToInt = {'ROCK': 0, 'PAPER': 1, 'SCISSORS': 2}; //Referenciramo izbor kao brojeve
const intToOutcome = ['Bob wins!', 'Draw!', 'Alice wins!']; //Konvertujemo broj u string
const {standardUnit} = reach;
const defaults = {defaultFundAmt: '10', defaultWager: '3', standardUnit}; //Defaultne vrednosti

class App extends React.Component {
  constructor(props) { //Konstruktor klase App
    super(props);
    this.state = {view: 'ConnectAccount', ...defaults}; //Postavljamo view i renderujemo default vrednosti
  }
  async componentDidMount() {
    const acc = await reach.getDefaultAccount();    //Odabira defaultni nalog
    const balAtomic = await reach.balanceOf(acc);   //Pitamo nalog koliko ima na stanju
    const bal = reach.formatCurrency(balAtomic, 4);
    this.setState({acc, bal});  
    if (await reach.canFundFromFaucet()) {
      this.setState({view: 'FundAccount'}); 
    } else {
      this.setState({view: 'DeployerOrAttacher'});
    }
  }
  async fundAccount(fundAmount) {     //Ako želi da fundira nalog
    await reach.fundFromFaucet(this.state.acc, reach.parseCurrency(fundAmount));
    this.setState({view: 'DeployerOrAttacher'});
  }
  async skipFundAccount() { this.setState({view: 'DeployerOrAttacher'}); }    //Ako ne želi da fundira nalog
  selectAttacher() { this.setState({view: 'Wrapper', ContentView: Attacher}); } //Ako izaberu Attacher view koji ćemo videti
  selectDeployer() { this.setState({view: 'Wrapper', ContentView: Deployer}); } //Ako izaberu Deployer view koji ćemo videti
  render() { return renderView(this, AppViews); } //Renderovanje App sekcije
}

class Player extends React.Component {  //Klasa Player
  random() { return reach.hasRandom.random(); } //Random metoda
  async getHand() { // Fun([], UInt) - nema argumenta i vraća UInt
    const hand = await new Promise(resolveHandP => {
      this.setState({view: 'GetHand', playable: true, resolveHandP}); //Biraju šta će pokazati
    });
    this.setState({view: 'WaitingForResults', hand}); //Sada igraču prikazujemo da čekamo na rezultat
    return handToInt[hand]; //Šaljemo odgovor kao int backend-u
  }
  seeOutcome(i) { this.setState({view: 'Done', outcome: intToOutcome[i]}); } //Definišemo seeOutcome funkciju za prikaz rezultata
  informTimeout() { this.setState({view: 'Timeout'}); } //Timeout
  playHand(hand) { this.state.resolveHandP(hand); } 
}

class Deployer extends Player { //Pravimo klasu Deployer koja nasleđuje klasu Player (To je Alice)
  constructor(props) { //Konstruktor
    super(props);
    this.state = {view: 'SetWager'}; //Tražimo da Alice stavi wager (ulog)
  }
  setWager(wager) { this.setState({view: 'Deploy', wager}); }
  async deploy() { //Deploying
    const ctc = this.props.acc.contract(backend);
    this.setState({view: 'Deploying', ctc}); //Ovaj view želimo da vidimo (Deploying)
    this.wager = reach.parseCurrency(this.state.wager); // UInt
    this.deadline = {ETH: 10, ALGO: 100, CFX: 1000}[reach.connector]; // Deadline koji je Alice dala prilagođen mreži
    backend.Alice(ctc, this);
    const ctcInfoStr = JSON.stringify(await ctc.getInfo(), null, 2); //Uzimamo info ugovora
    this.setState({view: 'WaitingForAttacher', ctcInfoStr}); //Postavljamo state WaitingForAttacher
  }
  render() { return renderView(this, DeployerViews); } //Render ovoj view-a, to je bilo za Alice
}
class Attacher extends Player { //Pravimo klasu Attacher koji nasleđuje Player (Ovo je Bob)
  constructor(props) {
    super(props);
    this.state = {view: 'Attach'};
  }
  attach(ctcInfoStr) { //Ovo samo Bob može da radi, Attach
    const ctc = this.props.acc.contract(backend, JSON.parse(ctcInfoStr));
    this.setState({view: 'Attaching'}); //Želimo da vidimo view za Attaching
    backend.Bob(ctc, this);
  }
  async acceptWager(wagerAtomic) { // Fun([UInt], Null) - Prihvatanje uloga
    const wager = reach.formatCurrency(wagerAtomic, 4);
    return await new Promise(resolveAcceptedP => {  //Pravimo promise i pitamo ga da li prihvata
      this.setState({view: 'AcceptTerms', wager, resolveAcceptedP}); 
    });
  }
  termsAccepted() {     //Šta se dešava kada prihvatimo uslove
    this.state.resolveAcceptedP(); //Postavljamo state da je prihvaćen
    this.setState({view: 'WaitingForTurn'});
  }
  render() { return renderView(this, AttacherViews); } //Render
}

renderDOM(<App />); //Renderovanje App klase