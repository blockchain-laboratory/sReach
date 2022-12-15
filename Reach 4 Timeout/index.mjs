import { loadStdlib } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);

const startingBalance = stdlib.parseCurrency(100);
const accAlice = await stdlib.newTestAccount(startingBalance);
const accBob = await stdlib.newTestAccount(startingBalance);

const fmt = (x) => stdlib.formatCurrency(x, 4);
const getBalance = async (who) => fmt(await stdlib.balanceOf(who));
const beforeAlice = await getBalance(accAlice);
const beforeBob = await getBalance(accBob);

const ctcAlice = accAlice.contract(backend);
const ctcBob = accBob.contract(backend, ctcAlice.getInfo());

const HAND = ['Rock', 'Paper', 'Scissors'];
const OUTCOME = ['Bob wins', 'Draw', 'Alice wins'];
const Player = (Who) => ({
  ...stdlib.hasRandom,
  getHand: () => {
    const hand = Math.floor(Math.random() * 3);
    console.log(`${Who} played ${HAND[hand]}`);
    return hand;
  },
  seeOutcome: (outcome) => {
    console.log(`${Who} saw outcome ${OUTCOME[outcome]}`);
  },
  informTimeout: () => {      //Implementacija f-je 
    console.log(`${Who} observed a timeout`);   //U konzoli se ispisuje ko je video timeout, f-ja se pokreće kad se desi timeout
  },
});

await Promise.all([
  ctcAlice.p.Alice({
    ...Player('Alice'),
    wager: stdlib.parseCurrency(5),
    deadline: 10, //Alice postavlja rok (deadline) (broj u blokovima)
  }),
  ctcBob.p.Bob({
    ...Player('Bob'),
    acceptWager: async (amt) => { // <-- async now
      if ( Math.random() <= 0.5 ) {       //Generisemo random timeout
        for ( let i = 0; i < 10; i++ ) {
          console.log(`  Bob takes his sweet time...`); //Bob ne odgovara, zato stavljamo posle wait block
          await stdlib.wait(1);
        }
      } else {
        console.log(`Bob accepts the wager of ${fmt(amt)}.`); //U ovom slučaju je sve regularno i on prihvata wager
      }
    },
  }),
]);

const afterAlice = await getBalance(accAlice);
const afterBob = await getBalance(accBob);

console.log(`Alice went from ${beforeAlice} to ${afterAlice}.`);
console.log(`Bob went from ${beforeBob} to ${afterBob}.`);
