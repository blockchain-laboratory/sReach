'reach 0.1';

//Definisanje enum-a za ruke koje mogu biti odabrane i moguće ishode
const [ isHand, ROCK, PAPER, SCISSORS ] = makeEnum(3);
const [ isOutcome, B_WINS, DRAW, A_WINS ] = makeEnum(3);

const winner = (handAlice, handBob) => //Računa pobednika igre
  ((handAlice + (4 - handBob)) % 3);

assert(winner(ROCK, PAPER) == B_WINS); //Tvrdi da kada Alice odigra Kamen i Bob odigra Papir, Bob pobeđuje kao što je i očekivano
assert(winner(PAPER, ROCK) == A_WINS);
assert(winner(ROCK, ROCK) == DRAW);

forall(UInt, handAlice =>
  forall(UInt, handBob =>
    assert(isOutcome(winner(handAlice, handBob))))); //Bez obzira na vrednosti za handAlice i handBob, winner će uvek vratiti validan ishod

forall(UInt, (hand) =>
  assert(winner(hand, hand) == DRAW)); //Ako su vrednosti jednake, ishod će uvek biti nerešeno

const Player = {
  ...hasRandom, // <--- new! Ovo koristimo kako bismo generisali nasumičan broj koji će štititi Alice-inu ruku(odabir)
  getHand: Fun([], UInt),
  seeOutcome: Fun([UInt], Null),
};

export const main = Reach.App(() => {
  const Alice = Participant('Alice', {
    ...Player,
    wager: UInt,
  });
  const Bob   = Participant('Bob', {
    ...Player,
    acceptWager: Fun([UInt], Null),
  });
  init();

  Alice.only(() => {
    const wager = declassify(interact.wager);
    const _handAlice = interact.getHand(); //Ova vrednost je hash-ova, ostaje tajna
    const [_commitAlice, _saltAlice] = makeCommitment(interact, _handAlice); //Osigurava da Alice ne može da promeni svoj odabir kasnije, ali njen odabir ostaje nepoznat
    const commitAlice = declassify(_commitAlice);
  });
  Alice.publish(wager, commitAlice)
    .pay(wager);
  commit();

  unknowable(Bob, Alice(_handAlice, _saltAlice)); //Osiguravamo da Bob ne zna vrednosti _handAlice ili _saltAlice, koje su privatne vrednosti
  Bob.only(() => {
    interact.acceptWager(wager);
    const handBob = declassify(interact.getHand());
  });
  Bob.publish(handBob)
    .pay(wager);
  commit();

  Alice.only(() => { //Alice otkriva svoje privatne vrednosti kako bi one mogle biti iskorišćene
    const saltAlice = declassify(_saltAlice);
    const handAlice = declassify(_handAlice);
  });
  Alice.publish(saltAlice, handAlice); //Alice objavljuje ove informacije
  checkCommitment(commitAlice, saltAlice, handAlice); //Proverava da li su objavljene vrednosti jednake originalnim vrednostima

  const outcome = winner(handAlice, handBob);
  const                 [forAlice, forBob] =
    outcome == A_WINS ? [       2,      0] :
    outcome == B_WINS ? [       0,      2] :
    /* tie           */ [       1,      1];
  transfer(forAlice * wager).to(Alice);
  transfer(forBob   * wager).to(Bob);
  commit();

  each([Alice, Bob], () => {
    interact.seeOutcome(outcome);
  });
});