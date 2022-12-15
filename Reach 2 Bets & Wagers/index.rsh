'reach 0.1';

const Player = {
  getHand: Fun([], UInt),
  seeOutcome: Fun([UInt], Null),
};

export const main = Reach.App(() => {
  const Alice = Participant('Alice', {
    ...Player,
    wager: UInt, //Samo Alice može da prosledi ovu informaciju
  });
  const Bob   = Participant('Bob', {
    ...Player,
    acceptWager: Fun([UInt], Null), //Preslikavanje frontend funckije, mora da se nalazi i u frontend-u i u backend-u
  });
  init();

  Alice.only(() => {
    const wager = declassify(interact.wager); //Poziva postavljanje opklade
    const handAlice = declassify(interact.getHand());
  });
  Alice.publish(wager, handAlice)
    .pay(wager); //Alice plaća određenu sumu(wager) u ugovor
  commit();

  Bob.only(() => {
    interact.acceptWager(wager); //Interaguje sa funkcijom iz frontend-a
    const handBob = declassify(interact.getHand());
  });
  Bob.publish(handBob)
    .pay(wager); //Bob takođe plaća, ugovor sada sadrži 2 sume opklade(wager)

  const outcome = (handAlice + (4 - handBob)) % 3;
  const            [forAlice, forBob] = //Ovo koristimo za isplaćivanje igračima
    outcome == 2 ? [       2,      0] : //2 sume opklade
    outcome == 0 ? [       0,      2] :
    /* tie      */ [       1,      1];
  transfer(forAlice * wager).to(Alice); //Transfer uzima tokene iz ugovora i šalje ih igračima
   transfer(forBob   * wager).to(Bob);
  commit();

  each([Alice, Bob], () => {
    interact.seeOutcome(outcome); //Alice i Bob vide ishod igre
  });
});