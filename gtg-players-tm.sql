-- ═══════════════════════════════════════════════════
-- GTG — EFFECTIFS LIGUE 1 2024/25 — VRAIES COTES TM
-- ═══════════════════════════════════════════════════
truncate public.players restart identity cascade;

insert into public.players (nom, club, poste, cote_tm, note_actuelle, nationalite) values

-- ══ PSG ══
('Gianluigi Donnarumma','PSG','GK',50000000,7.2,'Italienne'),
('Matvei Safonov','PSG','GK',18000000,6.5,'Russe'),
('Achraf Hakimi','PSG','DEF',80000000,7.5,'Marocaine'),
('Nuno Mendes','PSG','DEF',75000000,7.8,'Portugaise'),
('Willian Pacho','PSG','DEF',70000000,7.0,'Équatorienne'),
('Marquinhos','PSG','DEF',22000000,6.8,'Brésilienne'),
('Lucas Beraldo','PSG','DEF',22000000,6.5,'Brésilienne'),
('Nordi Mukiele','PSG','DEF',12000000,6.0,'Française'),
('Vitinha','PSG','MID',110000000,8.2,'Portugaise'),
('João Neves','PSG','MID',110000000,8.5,'Portugaise'),
('Désiré Doué','PSG','MID',90000000,7.5,'Française'),
('Warren Zaïre-Emery','PSG','MID',50000000,7.0,'Française'),
('Fabian Ruiz','PSG','MID',30000000,6.5,'Espagnole'),
('Lee Kang-In','PSG','MID',28000000,6.2,'Sud-Coréenne'),
('Carlos Soler','PSG','MID',15000000,6.0,'Espagnole'),
('Ousmane Dembélé','PSG','ATT',100000000,8.8,'Française'),
('Khvicha Kvaratskhelia','PSG','ATT',90000000,9.2,'Géorgienne'),
('Bradley Barcola','PSG','ATT',70000000,7.5,'Française'),
('Gonçalo Ramos','PSG','ATT',45000000,6.8,'Portugaise'),
('Senny Mayulu','PSG','ATT',30000000,6.0,'Française'),

-- ══ MARSEILLE ══
('Geronimo Rulli','OM','GK',12000000,6.5,'Argentine'),
('Rubén Blanco','OM','GK',8000000,6.2,'Espagnole'),
('Jonathan Clauss','OM','DEF',15000000,6.8,'Française'),
('Lilian Brassier','OM','DEF',12000000,6.8,'Française'),
('Samuel Gigot','OM','DEF',10000000,6.5,'Française'),
('Leonardo Balerdi','OM','DEF',18000000,7.0,'Argentine'),
('Quentin Merlin','OM','DEF',15000000,6.8,'Française'),
('Adrien Rabiot','OM','MID',15000000,6.5,'Française'),
('Pierre-Emile Hojbjerg','OM','MID',15000000,6.5,'Danoise'),
('Valentin Carboni','OM','MID',22000000,6.8,'Italienne'),
('Ismaël Bennacer','OM','MID',20000000,6.5,'Algérienne'),
('Mason Greenwood','OM','ATT',50000000,8.2,'Anglaise'),
('Luis Henrique','OM','ATT',20000000,7.0,'Brésilienne'),
('Elye Wahi','OM','ATT',25000000,6.8,'Française'),
('Neal Maupay','OM','ATT',8000000,6.2,'Française'),

-- ══ MONACO ══
('Alexander Nübel','Monaco','GK',20000000,7.0,'Allemande'),
('Radosław Majecki','Monaco','GK',8000000,6.2,'Polonaise'),
('Caio Henrique','Monaco','DEF',18000000,7.0,'Brésilienne'),
('Vanderson','Monaco','DEF',20000000,7.0,'Brésilienne'),
('Mohamed Salisu','Monaco','DEF',15000000,6.8,'Ghanéenne'),
('Wilfried Singo','Monaco','DEF',20000000,7.0,'Ivoirienne'),
('Chrislain Matsima','Monaco','DEF',15000000,6.5,'Française'),
('Mohamed Camara','Monaco','MID',30000000,7.0,'Malienne'),
('Denis Zakaria','Monaco','MID',18000000,6.5,'Suisse'),
('Aleksandr Golovin','Monaco','MID',20000000,6.8,'Russe'),
('Youssouf Fofana','Monaco','MID',35000000,7.5,'Française'),
('Maghnes Akliouche','Monaco','ATT',45000000,7.5,'Française'),
('Eliesse Ben Seghir','Monaco','ATT',35000000,7.2,'Française'),
('Breel Embolo','Monaco','ATT',18000000,7.0,'Suisse'),
('Wissam Ben Yedder','Monaco','ATT',15000000,6.8,'Française'),
('Folarin Balogun','Monaco','ATT',25000000,7.0,'Américaine'),

-- ══ LOSC LILLE ══
('Lucas Chevalier','LOSC','GK',40000000,7.5,'Française'),
('Alexsandro','LOSC','DEF',18000000,6.8,'Brésilienne'),
('Bafodé Diakité','LOSC','DEF',25000000,7.0,'Française'),
('Leny Yoro','LOSC','DEF',60000000,7.5,'Française'),
('Gabriel Gudmundsson','LOSC','DEF',12000000,6.5,'Suédoise'),
('Benjamin André','LOSC','MID',15000000,6.5,'Française'),
('Angel Gomes','LOSC','MID',35000000,7.2,'Anglaise'),
('Ayyoub Bouaddi','LOSC','MID',40000000,7.0,'Française'),
('Nabil Mukau','LOSC','MID',12000000,6.5,'Congolaise'),
('Hakon Haraldsson','LOSC','MID',15000000,6.5,'Islandaise'),
('Jonathan David','LOSC','ATT',65000000,8.0,'Canadienne'),
('Edon Zhegrova','LOSC','ATT',30000000,7.2,'Kosovare'),
('Mohamed Bayo','LOSC','ATT',12000000,6.5,'Guinéenne'),

-- ══ OLYMPIQUE LYONNAIS ══
('Lucas Perri','OL','GK',12000000,6.8,'Brésilienne'),
('Anthony Lopes','OL','GK',10000000,6.5,'Portugaise'),
('Saël Kumbedi','OL','DEF',15000000,7.0,'Française'),
('Nicolas Tagliafico','OL','DEF',8000000,6.5,'Argentine'),
('Jake O''Brien','OL','DEF',15000000,6.8,'Irlandaise'),
('Moussa Niakhaté','OL','DEF',18000000,6.8,'Sénégalaise'),
('Maxence Caqueret','OL','MID',18000000,6.8,'Française'),
('Corentin Tolisso','OL','MID',15000000,6.5,'Française'),
('Rayan Cherki','OL','MID',40000000,7.5,'Française'),
('Thiago Almada','OL','MID',22000000,7.0,'Argentine'),
('Alexandre Lacazette','OL','ATT',5000000,6.5,'Française'),
('Gift Orban','OL','ATT',18000000,6.8,'Nigériane'),
('Malick Fofana','OL','ATT',25000000,7.2,'Belge'),
('Ernest Nuamah','OL','ATT',20000000,6.8,'Ghanéenne'),

-- ══ RC LENS ══
('Brice Samba','Lens','GK',15000000,7.0,'Congolaise'),
('Kevin Danso','Lens','DEF',25000000,7.0,'Autrichienne'),
('Jonathan Gradit','Lens','DEF',10000000,6.5,'Française'),
('Deiver Machado','Lens','DEF',10000000,6.2,'Colombienne'),
('Salis Abdul Samed','Lens','MID',18000000,6.8,'Ghanéenne'),
('Andy Diouf','Lens','MID',20000000,7.0,'Française'),
('Angelo Fulgini','Lens','MID',12000000,6.5,'Française'),
('Neil El Aynaoui','Lens','MID',20000000,7.2,'Française'),
('Hugo Magnetti','Lens','MID',15000000,7.0,'Française'),
('Lois Openda','Lens','ATT',40000000,7.8,'Belge'),
('Florian Sotoca','Lens','ATT',8000000,6.5,'Française'),
('David Pereira da Costa','Lens','ATT',12000000,6.8,'Française'),

-- ══ RENNES ══
('Dogan Alemdar','Rennes','GK',10000000,6.5,'Turque'),
('Adrien Truffert','Rennes','DEF',15000000,7.0,'Française'),
('Arthur Theate','Rennes','DEF',20000000,7.0,'Belge'),
('Joe Rodon','Rennes','DEF',12000000,6.8,'Galloise'),
('Warmed Omari','Rennes','DEF',12000000,6.5,'Française'),
('Fabian Rieder','Rennes','MID',15000000,6.8,'Suisse'),
('Lovro Majer','Rennes','MID',20000000,7.0,'Croate'),
('Benjamin Bourigeaud','Rennes','MID',12000000,6.8,'Française'),
('Amine Gouiri','Rennes','ATT',22000000,7.2,'Française'),
('Martin Terrier','Rennes','ATT',18000000,6.8,'Française'),
('Arnaud Kalimuendo','Rennes','ATT',20000000,6.8,'Française'),
('Jérémy Doku','Rennes','ATT',35000000,7.5,'Belge'),

-- ══ OGC NICE ══
('Marcin Bulka','Nice','GK',15000000,7.0,'Polonaise'),
('Jean-Clair Todibo','Nice','DEF',28000000,7.2,'Française'),
('Melvin Bard','Nice','DEF',12000000,6.8,'Française'),
('Dante','Nice','DEF',5000000,6.5,'Brésilienne'),
('Youcef Atal','Nice','DEF',15000000,6.8,'Algérienne'),
('Manu Koné','Nice','MID',35000000,7.5,'Française'),
('Hicham Boudaoui','Nice','MID',15000000,6.8,'Algérienne'),
('Alexis Beka Beka','Nice','MID',12000000,6.5,'Française'),
('Mohamed-Ali Cho','Nice','ATT',20000000,7.0,'Française'),
('Martin Biereth','Nice','ATT',25000000,7.2,'Danoise'),
('Evann Guessand','Nice','ATT',15000000,6.8,'Française'),
('Terem Moffi','Nice','ATT',18000000,7.0,'Nigériane'),

-- ══ STRASBOURG ══
('Matz Sels','Strasbourg','GK',12000000,7.0,'Belge'),
('Gerzino Nyamsi','Strasbourg','DEF',10000000,6.5,'Française'),
('Colin Dagba','Strasbourg','DEF',8000000,6.2,'Française'),
('Jean-Ricner Bellegarde','Strasbourg','MID',15000000,7.0,'Française'),
('Dilane Bakwa','Strasbourg','MID',12000000,6.8,'Française'),
('Habib Diallo','Strasbourg','ATT',15000000,7.0,'Sénégalaise'),
('Emanuel Emegha','Strasbourg','ATT',15000000,7.0,'Néerlandaise'),

-- ══ TOULOUSE ══
('Guillaume Restes','Toulouse','GK',15000000,6.8,'Française'),
('Anthony Rouault','Toulouse','DEF',15000000,6.8,'Française'),
('Logan Costa','Toulouse','DEF',18000000,7.0,'Française'),
('Rasmus Nicolaisen','Toulouse','DEF',12000000,6.5,'Danoise'),
('Branco van den Boomen','Toulouse','MID',12000000,6.5,'Néerlandaise'),
('Zakaria Aboukhlal','Toulouse','ATT',15000000,6.8,'Marocaine'),
('Guillaume Dallinga','Toulouse','ATT',14000000,6.8,'Néerlandaise'),
('Rhys Healey','Toulouse','ATT',12000000,6.5,'Anglaise'),

-- ══ BREST ══
('Marco Bizot','Brest','GK',10000000,6.8,'Néerlandaise'),
('Brendan Chardonnet','Brest','DEF',10000000,6.5,'Française'),
('Bradley Locko','Brest','DEF',12000000,6.5,'Française'),
('Pierre Lees-Melou','Brest','MID',12000000,6.8,'Française'),
('Mahdi Camara','Brest','MID',12000000,6.5,'Française'),
('Romain del Castillo','Brest','MID',10000000,6.2,'Française'),
('Dango Ouattara','Brest','ATT',25000000,7.5,'Burkinabé'),
('Ludovic Ajorque','Brest','ATT',12000000,6.5,'Française'),
('Steve Mounié','Brest','ATT',8000000,6.2,'Béninoise'),

-- ══ LORIENT ══
('Yvon Mvogo','Lorient','GK',8000000,6.5,'Suisse'),
('Julien Laporte','Lorient','DEF',10000000,6.5,'Française'),
('Moritz Jenz','Lorient','DEF',10000000,6.2,'Allemande'),
('Enzo Le Fée','Lorient','MID',20000000,7.0,'Française'),
('Laurent Abergel','Lorient','MID',8000000,6.2,'Française'),
('Bamba Dieng','Lorient','ATT',12000000,6.5,'Sénégalaise'),
('Ibrahima Koné','Lorient','ATT',12000000,6.8,'Malienne'),

-- ══ ANGERS ══
('Yahia Fofana','Angers','GK',8000000,6.5,'Ivoirienne'),
('Florent Hanin','Angers','DEF',8000000,6.2,'Française'),
('Haris Belkebla','Angers','MID',8000000,6.2,'Algérienne'),
('Himad Abdelli','Angers','MID',10000000,6.5,'Algérienne'),
('Oussama El Azzouzi','Angers','MID',12000000,6.5,'Marocaine'),
('Estéban Lepaul','Angers','ATT',18000000,7.5,'Française'),

-- ══ PARIS FC ══
('Alban Lafont','Paris FC','GK',8000000,6.5,'Française'),
('Amir Richardson','Paris FC','MID',12000000,6.5,'Marocaine'),
('Yann Kitala','Paris FC','ATT',10000000,6.5,'Française'),

-- ══ LE HAVRE ══
('Arthur Desmas','Le Havre','GK',10000000,6.5,'Française'),
('Odsonne Edouard','Le Havre','ATT',15000000,6.8,'Française'),
('André-Frank Zambo Anguissa','Le Havre','MID',15000000,6.8,'Camerounaise'),

-- ══ AUXERRE ══
('Donovan Léon','Auxerre','GK',8000000,6.5,'Française'),
('Sinaly Diomandé','Auxerre','DEF',12000000,6.8,'Ivoirienne'),
('Elisha Owusu','Auxerre','MID',10000000,6.5,'Ghanéenne'),
('Ibrahim Osman','Auxerre','ATT',15000000,7.0,'Ghanéenne'),
('Lassine Sinayoko','Auxerre','ATT',10000000,6.5,'Malienne'),

-- ══ NANTES ══
('Alban Lafont','Nantes','GK',8000000,6.5,'Française'),
('Jean-Charles Castelletto','Nantes','DEF',8000000,6.2,'Camerounaise'),
('Pedro Chirivella','Nantes','MID',8000000,6.2,'Espagnole'),
('Mostafa Mohamed','Nantes','ATT',12000000,6.5,'Égyptienne'),
('Matthis Abline','Nantes','ATT',10000000,6.5,'Française'),

-- ══ METZ ══
('Thomas Didillon','Metz','GK',8000000,6.2,'Française'),
('Dylan Bronn','Metz','DEF',8000000,6.2,'Tunisienne'),
('Georges Mikautadze','Metz','ATT',20000000,7.0,'Géorgienne'),
('Farid Boulaya','Metz','MID',8000000,6.2,'Algérienne')

on conflict do nothing;

select count(*) as total_joueurs from public.players;
