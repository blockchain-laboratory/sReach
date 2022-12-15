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
  informTimeout: Fun([], Null),
};

export const main = Reach.App(() => {
  const Alice = Participant('Alice', {
    ...Player,
    wager: UInt, // atomic units of currency
    deadline: UInt, // time delta (blocks/rounds)
  });
  const Bob   = Participant('Bob', {
    ...Player,
    acceptWager: Fun([UInt], Null),
  });
  init();

  const informTimeout = () => {
    each([Alice, Bob], () => {
      interact.informTimeout();
    });
  };

  Alice.only(() => {
    const wager = declassify(interact.wager);
    const deadline = declassify(interact.deadline);
  });
  Alice.publish(wager, deadline)  //Alice plaća wager i publish-uje deadline
    .pay(wager);
  commit();

  Bob.only(() => {
    interact.acceptWager(wager); //Bob prihvata wager
  });
  Bob.pay(wager)
    .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout)); //Timeout

  var outcome = DRAW;    //Varijabla outcome koja je DRAW (izjednačeno)
  invariant( balance() == 2 * wager && isOutcome(outcome) ); //Uslov koji mora biti istinit i nepromenljiv je (šta se ne menja pre, u toku i posle petlje)
  while ( outcome == DRAW ) {   //While petlja - DOK je varijabla outcome jednaka DRAW
    commit(); //Prelazimo iz consensus-a u local step

    Alice.only(() => {      
      const _handAlice = interact.getHand();  //Šta je Alice pokazala
      const [_commitAlice, _saltAlice] = makeCommitment(interact, _handAlice); //Jedinstvena veza između vrednosti i commitmenta
      const commitAlice = declassify(_commitAlice); //Šta je Alice pokazala je i dalje sakriveno, otkriva se samo commitment
    });
    Alice.publish(commitAlice)
      .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout)); //Timeout ako Bob ne odgovori
    commit();

    unknowable(Bob, Alice(_handAlice, _saltAlice)); //Sada znamo da Bob ne može da zna Alicinu privatnu vrednost šta je pokazala 
    Bob.only(() => {
      const handBob = declassify(interact.getHand());
    });
    Bob.publish(handBob) //Bob publishuje šta je pokazao
      .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout)); //Timeout
    commit();

    Alice.only(() => {    //Sada možemo da otkrijemo Aliceine vrednosti
      const saltAlice = declassify(_saltAlice); 
      const handAlice = declassify(_handAlice);
    });
    Alice.publish(saltAlice, handAlice)   //Alice publishuje info da možemo da ih koristimo
      .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout)); //Timeout (za slučaj da ne odgovori)
    checkCommitment(commitAlice, saltAlice, handAlice); //Proveravamo da li je Alice probala da promeni ono što je pokazala na početku

    outcome = winner(handAlice, handBob);   //Ažuriramo vrednost varijable petlje outcome (funkciji winner šaljemo vrednosti a ona vraća outcome)
    continue;   //Reach traži continue za WHILE petlje (vraća se na uslov petlje)
  }   //Kraj petlje

  assert(outcome == A_WINS || outcome == B_WINS);   //Proveravamo da li je outcome A pobedila ili B pobedio
  transfer(2 * wager).to(outcome == A_WINS ? Alice : Bob);  //Prebacivanje wager-a onome ko je pobedio
  commit(); //Izlazimo iz consensus operacije

  each([Alice, Bob], () => {
    interact.seeOutcome(outcome); //Prikaži outcome za svakog
  });
});
