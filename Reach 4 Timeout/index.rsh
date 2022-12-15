'reach 0.1';

const [ isHand, ROCK, PAPER, SCISSORS ] = makeEnum(3);
const [ isOutcome, B_WINS, DRAW, A_WINS ] = makeEnum(3);

const winner = (handAlice, handBob) =>
  ((handAlice + (4 - handBob)) % 3);

assert(winner(ROCK, PAPER) == B_WINS);
assert(winner(PAPER, ROCK) == A_WINS);
assert(winner(ROCK, ROCK) == DRAW);

forall(UInt, handAlice =>
  forall(UInt, handBob =>
    assert(isOutcome(winner(handAlice, handBob)))));

forall(UInt, (hand) =>
  assert(winner(hand, hand) == DRAW));

const Player = {
  ...hasRandom,
  getHand: Fun([], UInt),
  seeOutcome: Fun([UInt], Null),
  informTimeout: Fun([], Null),     //Funkcija koju oba igrača moraju da imaju da vide da se Timeout desio
};

export const main = Reach.App(() => {
  const Alice = Participant('Alice', {
    ...Player,
    wager: UInt, // atomic units of currency
    deadline: UInt, // //Vremenski period (rok) do kog moramo odgovoriti (u blokovima)
  });
  const Bob   = Participant('Bob', {
    ...Player,
    acceptWager: Fun([UInt], Null),
  });
  init();

  const informTimeout = () => {     //Pomoćna f-ja koja pokazuje vreme
    each([Alice, Bob], () => {      
      interact.informTimeout();     //Pokreće frontend funkciju za Alice i Boba (EACH)
    });
  };

  Alice.only(() => {
    const wager = declassify(interact.wager);
    const _handAlice = interact.getHand();
    const [_commitAlice, _saltAlice] = makeCommitment(interact, _handAlice);
    const commitAlice = declassify(_commitAlice);
    const deadline = declassify(interact.deadline); //Kažemo da Alice daje rok (deadline)
  });
  Alice.publish(wager, commitAlice, deadline) //Alice publish-uje deadline da bismo mogli da ga koristimo
    .pay(wager);
  commit();

  unknowable(Bob, Alice(_handAlice, _saltAlice));
  Bob.only(() => {
    interact.acceptWager(wager);
    const handBob = declassify(interact.getHand());
  });
  Bob.publish(handBob)
    .pay(wager)
    .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));  //Bob-u dajemo vreme da reaguje (deadline), ako ne zatvara kod Alice i uništava ugovor, i izlazimo ovde, ne nastavljamo kod
  commit();

  Alice.only(() => {
    const saltAlice = declassify(_saltAlice);
    const handAlice = declassify(_handAlice);
  });
  Alice.publish(saltAlice, handAlice)
    .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout)); //Sada čekamo Alice, i ako ona ne odgovori, zatvaramo kod Boba (štitimo Boba od toga da Alice ne odgovori)
  checkCommitment(commitAlice, saltAlice, handAlice);

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
