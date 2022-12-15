'reach 0.1'; //Verzija Reach-a koje će biti korišćena

const Player = {  //Definišemo funkcije getHand i seeOutcome u objektu Player
  getHand: Fun([], UInt),
  seeOutcome: Fun([UInt], Null),
};

export const main = Reach.App(() => { //Pravljenje Reach Aplikacije
  const Alice = Participant('Alice', { //Definisanje participana
    //Specifikacija Alice-inog interact interfejsa ide ovde
    ...Player, //Korisnik može koristiti sve funkcije iz Player-a
  });
  const Bob   = Participant('Bob', {
    ...Player,
  });
  init();
// Ovde se piše program
  Alice.only(() => { //Alice ulazi u lokalni step i čuva svoj izbor u handAlice
    const handAlice = declassify(interact.getHand()); 
    //Koristimo frontend funkciju pa moramo da interact. sa njom, takođe je hash-ovana pa moramo da iskoristimo declassify (koji je prevodi) da bismo je koristili
  });
  Alice.publish(handAlice); //Objavljujemo Alice-inu ruku(odabir) na blockchain, i ulazimo u Consensus step
  commit(); //Pomeranje u sledeći step

  Bob.only(() => {
    const handBob = declassify(interact.getHand());
  });
  Bob.publish(handBob);

  const outcome = (handAlice + (4 - handBob)) % 3; //Izračunavanje ishoda igre
  commit();

  each([Alice, Bob], () => { //Alice i Bob zajedno ulaze u lokalni step i izvršavaju identičan kod
    interact.seeOutcome(outcome);
  });
});