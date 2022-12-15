// Ovo je modifikovani JavaScript fajl (frontend)
import { loadStdlib } from '@reach-sh/stdlib'; //Importovanje standardne Reach biblioteke
import * as backend from './build/index.main.mjs'; //Importovanje backend-a iz drugog fajla, koji je u subfolderu: main
const stdlib = loadStdlib(process.env);

const startingBalance = stdlib.parseCurrency(100); //Kreiranje konstante za početno stanje
const accAlice = await stdlib.newTestAccount(startingBalance); //Kreiranje test računa
const accBob = await stdlib.newTestAccount(startingBalance);

const ctcAlice = accAlice.contract(backend); //Alice je jedan od participanata u ovom ugovoru, ona se prikačuje na bilo koji ugovor
const ctcBob = accBob.contract(backend, ctcAlice.getInfo()); //Bob se prikačuje za Alice-in ugovor, kako bi se pridružio istom

//Definisanje mogućih odabira i ishoda
const HAND = ['Rock', 'Paper', 'Scissors'];
const OUTCOME = ['Bob wins', 'Draw', 'Alice wins'];
const Player = (Who) => ({
  getHand: () => {
    const hand = Math.floor(Math.random() * 3); //Čuvanje odabira igrača, dodeljivanjem nasumičnog broja(odabira)
    console.log(`${Who} played ${HAND[hand]}`); //Prikazivanje ko je odabrao koji odabir
    return hand;
  },
  seeOutcome: (outcome) => {
    console.log(`${Who} saw outcome ${OUTCOME[outcome]}`); //Prikaz ishoda
  },
});

await Promise.all([
  ctcAlice.p.Alice({
    ...Player('Alice'), //Preslikava logiku iz backend-a
  }),
  ctcBob.p.Bob({
    ...Player('Bob'),
  }),
]);