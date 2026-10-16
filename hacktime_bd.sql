-- =====================================================================
--  Smart Hackathon Management (HackTime) - base de donnees commune
--  Oracle Database XE 11g - groupe ELITE HACKERS
--
--  Modules du cahier des specifications :
--    1. Gestion des Competitions  -> table COMPETITION
--    2. Gestion des Ateliers      -> table ATELIER
--    3. Gestion des Employes      -> table EMPLOYE (+ authentification)
--    4. Gestion des Equipes       -> table EQUIPE
--    5. Gestion des Participants  -> table PARTICIPANT
--  Tables de support (necessaires aux metiers avances / innovants) :
--    SALLE, SPONSOR,
--    JUGER (jury), SPONSORISER, INSCRIPTION_ATELIER (presence + certificat),
--    AFFECTATION (charge de travail des employes)
--
--  Execution dans "Run SQL Command Line" :
--     connect projet2a/hacktime
--     @C:\Users\yahia\OneDrive\Documents\Projet2A\hacktime_bd.sql
--
--  Le script peut etre relance : il supprime d'abord les anciens objets.
--  Valeurs codees sans accents (PRESENTIEL, PLANIFIEE...) pour eviter les
--  problemes d'encodage entre SQL*Plus et Qt.
-- =====================================================================

SET DEFINE OFF

-- ---------------------------------------------------------------------
-- 0. Nettoyage (rien n'est supprime si les objets n'existent pas encore)
-- ---------------------------------------------------------------------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('INSCRIPTION_ATELIER','AFFECTATION','SPONSORISER',
                                 'JUGER','ASSISTER','PARTICIPANT','ATELIER','EQUIPE',
                                 'COMPETITION','SPONSOR','SALLE','EMPLOYE')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name LIKE 'SEQ\_%' ESCAPE '\') LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------

-- MODULE GESTION DES EMPLOYES (sert aussi a l'authentification par role)
CREATE TABLE employe (
  id_employe        NUMBER        CONSTRAINT pk_employe PRIMARY KEY,
  nom               VARCHAR2(50)  NOT NULL,
  prenom            VARCHAR2(50)  NOT NULL,
  email             VARCHAR2(100) NOT NULL CONSTRAINT uq_employe_email UNIQUE,
  telephone         VARCHAR2(15),
  poste             VARCHAR2(50)  NOT NULL,
  departement       VARCHAR2(50)  NOT NULL,
  date_embauche     DATE          DEFAULT SYSDATE NOT NULL,
  statut            VARCHAR2(15)  DEFAULT 'ACTIF' NOT NULL
                    CONSTRAINT ck_employe_statut
                    CHECK (statut IN ('ACTIF','EN_CONGE','INACTIF')),
  competences       VARCHAR2(300),               -- ex. 'Qt, IA, Pitch' (affectation intelligente)
  charge_max_heures NUMBER(3)     DEFAULT 40     -- seuil d'alerte de surcharge par semaine
                    CONSTRAINT ck_employe_charge CHECK (charge_max_heures > 0),
  login             VARCHAR2(30)  NOT NULL CONSTRAINT uq_employe_login UNIQUE,
  mot_de_passe      VARCHAR2(64)  NOT NULL,
  role              VARCHAR2(30)  NOT NULL
                    CONSTRAINT ck_employe_role
                    CHECK (role IN ('ADMINISTRATEUR','ORGANISATEUR','JURY',
                                    'RESPONSABLE_PEDAGOGIQUE','FORMATEUR','RESPONSABLE_RH'))
);

CREATE TABLE salle (
  id_salle   NUMBER        CONSTRAINT pk_salle PRIMARY KEY,
  nom_salle  VARCHAR2(50)  NOT NULL CONSTRAINT uq_salle_nom UNIQUE,
  capacite   NUMBER(4)     NOT NULL CONSTRAINT ck_salle_capacite CHECK (capacite > 0)
);

CREATE TABLE sponsor (
  id_sponsor  NUMBER        CONSTRAINT pk_sponsor PRIMARY KEY,
  nom_sponsor VARCHAR2(60)  NOT NULL CONSTRAINT uq_sponsor_nom UNIQUE,
  email       VARCHAR2(100),
  telephone   VARCHAR2(15)
);

-- MODULE GESTION DES COMPETITIONS
CREATE TABLE competition (
  id_competition  NUMBER         CONSTRAINT pk_competition PRIMARY KEY,
  nom             VARCHAR2(100)  NOT NULL,
  theme           VARCHAR2(40)   NOT NULL,
  date_debut      DATE           NOT NULL,
  date_fin        DATE           NOT NULL,
  mode_comp       VARCHAR2(15)   NOT NULL
                  CONSTRAINT ck_comp_mode
                  CHECK (mode_comp IN ('PRESENTIEL','EN_LIGNE','HYBRIDE')),
  max_equipes     NUMBER(3)      DEFAULT 5 NOT NULL
                  CONSTRAINT ck_comp_max CHECK (max_equipes BETWEEN 1 AND 50),
  statut          VARCHAR2(15)   DEFAULT 'PLANIFIEE' NOT NULL
                  CONSTRAINT ck_comp_statut
                  CHECK (statut IN ('PLANIFIEE','EN_COURS','TERMINEE')),
  description     VARCHAR2(500),
  id_salle        NUMBER         CONSTRAINT fk_comp_salle
                                 REFERENCES salle(id_salle) ON DELETE SET NULL,
  id_organisateur NUMBER         CONSTRAINT fk_comp_organisateur
                                 REFERENCES employe(id_employe) ON DELETE SET NULL,
  CONSTRAINT ck_comp_dates CHECK (date_fin >= date_debut)
);

-- Equipes inscrites a une competition (statistiques : nb d'equipes, taux de participation)
CREATE TABLE equipe (
  id_equipe        NUMBER        CONSTRAINT pk_equipe PRIMARY KEY,
  nom_equipe       VARCHAR2(60)  NOT NULL,
  nom_projet       VARCHAR2(100),
  date_inscription DATE          DEFAULT SYSDATE,
  score            NUMBER(5,2)   CONSTRAINT ck_equipe_score CHECK (score BETWEEN 0 AND 20),
  id_competition   NUMBER        NOT NULL CONSTRAINT fk_equipe_comp
                                 REFERENCES competition(id_competition) ON DELETE CASCADE,
  CONSTRAINT uq_equipe_nom UNIQUE (nom_equipe, id_competition)
);

-- Participants (membres d'equipe et inscrits aux ateliers)
CREATE TABLE participant (
  id_participant  NUMBER        CONSTRAINT pk_participant PRIMARY KEY,
  nom             VARCHAR2(50)  NOT NULL,
  prenom          VARCHAR2(50)  NOT NULL,
  email           VARCHAR2(100) NOT NULL CONSTRAINT uq_participant_email UNIQUE,
  telephone       VARCHAR2(15),
  etablissement   VARCHAR2(80),
  niveau          VARCHAR2(15)  CONSTRAINT ck_participant_niveau
                                CHECK (niveau IN ('DEBUTANT','INTERMEDIAIRE','AVANCE')),
  competences     VARCHAR2(300),               -- profil pour la recommandation d'ateliers
  id_equipe       NUMBER        CONSTRAINT fk_participant_equipe
                                REFERENCES equipe(id_equipe) ON DELETE SET NULL
);

-- MODULE GESTION DES ATELIERS
CREATE TABLE atelier (
  id_atelier     NUMBER         CONSTRAINT pk_atelier PRIMARY KEY,
  titre          VARCHAR2(100)  NOT NULL,
  categorie      VARCHAR2(40)   NOT NULL,
  date_heure     DATE           NOT NULL,      -- DATE Oracle = date + heure
  duree_minutes  NUMBER(4)      NOT NULL CONSTRAINT ck_atelier_duree CHECK (duree_minutes > 0),
  capacite       NUMBER(4)      NOT NULL CONSTRAINT ck_atelier_capacite CHECK (capacite > 0),
  statut         VARCHAR2(15)   DEFAULT 'PLANIFIE' NOT NULL
                 CONSTRAINT ck_atelier_statut
                 CHECK (statut IN ('PLANIFIE','EN_COURS','TERMINE','ANNULE')),
  description    VARCHAR2(500),
  id_formateur   NUMBER         CONSTRAINT fk_atelier_formateur
                                REFERENCES employe(id_employe) ON DELETE SET NULL,
  id_salle       NUMBER         CONSTRAINT fk_atelier_salle
                                REFERENCES salle(id_salle) ON DELETE SET NULL,
  id_competition NUMBER         CONSTRAINT fk_atelier_comp
                                REFERENCES competition(id_competition) ON DELETE SET NULL
);

-- Association N-N : jury d'une competition (detection des conflits de jury)
CREATE TABLE juger (
  id_competition NUMBER CONSTRAINT fk_juger_comp
                        REFERENCES competition(id_competition) ON DELETE CASCADE,
  id_employe     NUMBER CONSTRAINT fk_juger_employe
                        REFERENCES employe(id_employe) ON DELETE CASCADE,
  CONSTRAINT pk_juger PRIMARY KEY (id_competition, id_employe)
);

-- Association N-N : sponsors d'une competition (brochures / publicites PDF)
CREATE TABLE sponsoriser (
  id_competition NUMBER CONSTRAINT fk_spons_comp
                        REFERENCES competition(id_competition) ON DELETE CASCADE,
  id_sponsor     NUMBER CONSTRAINT fk_spons_sponsor
                        REFERENCES sponsor(id_sponsor) ON DELETE CASCADE,
  montant        NUMBER(10,2) CONSTRAINT ck_spons_montant CHECK (montant >= 0),
  CONSTRAINT pk_sponsoriser PRIMARY KEY (id_competition, id_sponsor)
);

-- Association N-N : inscription d'un participant a un atelier
-- (taux de participation + certificat PDF avec QR code)
CREATE TABLE inscription_atelier (
  id_participant   NUMBER CONSTRAINT fk_insc_part
                          REFERENCES participant(id_participant) ON DELETE CASCADE,
  id_atelier       NUMBER CONSTRAINT fk_insc_atelier
                          REFERENCES atelier(id_atelier) ON DELETE CASCADE,
  date_inscription DATE    DEFAULT SYSDATE,
  present          CHAR(1) DEFAULT 'N' CONSTRAINT ck_insc_present CHECK (present IN ('O','N')),
  code_certificat  VARCHAR2(40) CONSTRAINT uq_insc_certificat UNIQUE,  -- contenu du QR code
  CONSTRAINT pk_inscription_atelier PRIMARY KEY (id_participant, id_atelier)
);

-- Affectation d'un employe a une tache sur une competition
-- (suivi de la charge de travail + affectation intelligente)
CREATE TABLE affectation (
  id_affectation NUMBER        CONSTRAINT pk_affectation PRIMARY KEY,
  id_employe     NUMBER        NOT NULL CONSTRAINT fk_aff_employe
                               REFERENCES employe(id_employe) ON DELETE CASCADE,
  id_competition NUMBER        NOT NULL CONSTRAINT fk_aff_comp
                               REFERENCES competition(id_competition) ON DELETE CASCADE,
  tache          VARCHAR2(100) NOT NULL,
  date_debut     DATE          NOT NULL,
  date_fin       DATE          NOT NULL,
  nb_heures      NUMBER(4)     NOT NULL CONSTRAINT ck_aff_heures CHECK (nb_heures > 0),
  CONSTRAINT ck_aff_dates CHECK (date_fin >= date_debut)
);

-- ---------------------------------------------------------------------
-- 2. Sequences + triggers (auto-increment : Oracle 11g n'a pas IDENTITY)
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_employe     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_salle       START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_sponsor     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_competition START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_equipe      START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_participant START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_atelier     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_affectation START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE TRIGGER trg_employe BEFORE INSERT ON employe FOR EACH ROW
WHEN (NEW.id_employe IS NULL)
BEGIN SELECT seq_employe.NEXTVAL INTO :NEW.id_employe FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_salle BEFORE INSERT ON salle FOR EACH ROW
WHEN (NEW.id_salle IS NULL)
BEGIN SELECT seq_salle.NEXTVAL INTO :NEW.id_salle FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_sponsor BEFORE INSERT ON sponsor FOR EACH ROW
WHEN (NEW.id_sponsor IS NULL)
BEGIN SELECT seq_sponsor.NEXTVAL INTO :NEW.id_sponsor FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_competition BEFORE INSERT ON competition FOR EACH ROW
WHEN (NEW.id_competition IS NULL)
BEGIN SELECT seq_competition.NEXTVAL INTO :NEW.id_competition FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_equipe BEFORE INSERT ON equipe FOR EACH ROW
WHEN (NEW.id_equipe IS NULL)
BEGIN SELECT seq_equipe.NEXTVAL INTO :NEW.id_equipe FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_participant BEFORE INSERT ON participant FOR EACH ROW
WHEN (NEW.id_participant IS NULL)
BEGIN SELECT seq_participant.NEXTVAL INTO :NEW.id_participant FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_atelier BEFORE INSERT ON atelier FOR EACH ROW
WHEN (NEW.id_atelier IS NULL)
BEGIN SELECT seq_atelier.NEXTVAL INTO :NEW.id_atelier FROM dual; END;
/
CREATE OR REPLACE TRIGGER trg_affectation BEFORE INSERT ON affectation FOR EACH ROW
WHEN (NEW.id_affectation IS NULL)
BEGIN SELECT seq_affectation.NEXTVAL INTO :NEW.id_affectation FROM dual; END;
/

-- ---------------------------------------------------------------------
-- 3. Donnees de test
-- ---------------------------------------------------------------------
-- Comptes de connexion actuels de l'application (ids 1 a 3)
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Admin', 'HackTime', 'admin@hacktime.tn', 'Administrateur systeme', 'Direction', 'Gestion, Qt', 'hacktime123', 'hacktime123', 'ADMINISTRATEUR');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Mejri', 'Rania', 'rania.mejri@hacktime.tn', 'Organisatrice', 'Evenementiel', 'Logistique, Communication', 'hacktime', 'hacktime', 'ORGANISATEUR');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Jury', 'HackTime', 'jury@hacktime.tn', 'Membre du jury', 'Evaluation', 'Evaluation', 'hacktime321', 'hacktime321', 'JURY');
-- Jury (ids 4 a 8)
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Ben Ali', 'Sami', 'sami.benali@hacktime.tn', 'Membre du jury', 'Evaluation', 'IA, Environnement', 'sbenali', 'jury2025', 'JURY');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Trabelsi', 'Leila', 'leila.trabelsi@hacktime.tn', 'Membre du jury', 'Evaluation', 'Agriculture, Finance', 'ltrabelsi', 'jury2025', 'JURY');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Jaziri', 'Karim', 'karim.jaziri@hacktime.tn', 'Membre du jury', 'Evaluation', 'Sante, Ville intelligente', 'kjaziri', 'jury2025', 'JURY');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Gharbi', 'Nour', 'nour.gharbi@hacktime.tn', 'Membre du jury', 'Evaluation', 'Education', 'ngharbi', 'jury2025', 'JURY');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Hamdi', 'Youssef', 'youssef.hamdi@hacktime.tn', 'Membre du jury', 'Evaluation', 'Web, Mobile, Finance', 'yhamdi', 'jury2025', 'JURY');
-- Formateurs, pedagogie, RH (ids 9 a 12)
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Bouazizi', 'Mehdi', 'mehdi.bouazizi@hacktime.tn', 'Formateur', 'Formation', 'Git, Qt, C++', 'mbouazizi', 'form2025', 'FORMATEUR');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Chaabane', 'Hiba', 'hiba.chaabane@hacktime.tn', 'Formatrice', 'Formation', 'IA, Python, Pitch', 'hchaabane', 'form2025', 'FORMATEUR');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Ayari', 'Walid', 'walid.ayari@hacktime.tn', 'Responsable pedagogique', 'Formation', 'Pedagogie', 'wayari', 'peda2025', 'RESPONSABLE_PEDAGOGIQUE');
INSERT INTO employe (nom, prenom, email, poste, departement, competences, login, mot_de_passe, role)
  VALUES ('Feki', 'Salma', 'salma.feki@hacktime.tn', 'Responsable RH', 'Ressources humaines', 'Recrutement, Planning', 'sfeki', 'rh2025', 'RESPONSABLE_RH');

-- Salles (ids 1 a 6)
INSERT INTO salle (nom_salle, capacite) VALUES ('Amphi 1', 200);
INSERT INTO salle (nom_salle, capacite) VALUES ('Amphi 2', 150);
INSERT INTO salle (nom_salle, capacite) VALUES ('Salle A', 40);
INSERT INTO salle (nom_salle, capacite) VALUES ('Salle B', 40);
INSERT INTO salle (nom_salle, capacite) VALUES ('Lab Innovation', 30);
INSERT INTO salle (nom_salle, capacite) VALUES ('Espace Coworking', 60);

-- Sponsors (ids 1 a 8)
INSERT INTO sponsor (nom_sponsor) VALUES ('TechNova');
INSERT INTO sponsor (nom_sponsor) VALUES ('GreenBank');
INSERT INTO sponsor (nom_sponsor) VALUES ('MedLink');
INSERT INTO sponsor (nom_sponsor) VALUES ('DataWave');
INSERT INTO sponsor (nom_sponsor) VALUES ('EduPlus');
INSERT INTO sponsor (nom_sponsor) VALUES ('CloudPeak');
INSERT INTO sponsor (nom_sponsor) VALUES ('AgriSmart');
INSERT INTO sponsor (nom_sponsor) VALUES ('FinUp');

-- Competitions (ids 1 a 8)
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('Hack for a Better Future', 'Environnement', TO_DATE('12/05/2025','DD/MM/YYYY'), TO_DATE('14/05/2025','DD/MM/YYYY'),
          'PRESENTIEL', 5, 'PLANIFIEE', 'Solutions numeriques pour reduire les dechets et l''empreinte carbone.', 1, 2);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('HealthTech Innovation', 'Sante', TO_DATE('20/05/2025','DD/MM/YYYY'), TO_DATE('22/05/2025','DD/MM/YYYY'),
          'HYBRIDE', 4, 'EN_COURS', 'Suivi des patients et aide au diagnostic.', 5, 2);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('EduTech Solutions', 'Education', TO_DATE('28/04/2025','DD/MM/YYYY'), TO_DATE('30/04/2025','DD/MM/YYYY'),
          'PRESENTIEL', 6, 'TERMINEE', 'Rendre l''apprentissage plus accessible.', 1, 2);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('Smart City Challenge', 'Ville intelligente', TO_DATE('10/06/2025','DD/MM/YYYY'), TO_DATE('12/06/2025','DD/MM/YYYY'),
          'PRESENTIEL', 5, 'PLANIFIEE', 'Mobilite, energie et services urbains connectes.', 4, 1);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('AgriTech for Tomorrow', 'Agriculture', TO_DATE('18/06/2025','DD/MM/YYYY'), TO_DATE('20/06/2025','DD/MM/YYYY'),
          'EN_LIGNE', 3, 'EN_COURS', 'Capteurs et donnees pour une agriculture durable.', NULL, 2);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('AI for Good', 'Intelligence artificielle', TO_DATE('25/03/2025','DD/MM/YYYY'), TO_DATE('27/03/2025','DD/MM/YYYY'),
          'EN_LIGNE', 4, 'TERMINEE', 'Projets d''IA a impact social positif.', NULL, 1);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('Web & Mobile Dev', 'Developpement', TO_DATE('15/07/2025','DD/MM/YYYY'), TO_DATE('17/07/2025','DD/MM/YYYY'),
          'HYBRIDE', 5, 'PLANIFIEE', 'Une application web ou mobile utile aux etudiants.', 5, 2);
INSERT INTO competition (nom, theme, date_debut, date_fin, mode_comp, max_equipes, statut, description, id_salle, id_organisateur)
  VALUES ('FinTech Hack', 'Finance', TO_DATE('22/07/2025','DD/MM/YYYY'), TO_DATE('24/07/2025','DD/MM/YYYY'),
          'PRESENTIEL', 6, 'PLANIFIEE', 'Paiement, epargne et inclusion financiere.', 2, 1);

-- Jurys
INSERT INTO juger VALUES (1, 4);
INSERT INTO juger VALUES (1, 5);
INSERT INTO juger VALUES (2, 4);
INSERT INTO juger VALUES (2, 6);
INSERT INTO juger VALUES (3, 7);
INSERT INTO juger VALUES (4, 6);
INSERT INTO juger VALUES (4, 7);
INSERT INTO juger VALUES (5, 5);
INSERT INTO juger VALUES (6, 4);
INSERT INTO juger VALUES (7, 8);
INSERT INTO juger VALUES (8, 8);
INSERT INTO juger VALUES (8, 5);

-- Sponsors des competitions
INSERT INTO sponsoriser VALUES (1, 1, 5000);
INSERT INTO sponsoriser VALUES (1, 2, 3000);
INSERT INTO sponsoriser VALUES (2, 3, 4000);
INSERT INTO sponsoriser VALUES (2, 4, 2500);
INSERT INTO sponsoriser VALUES (3, 5, 2000);
INSERT INTO sponsoriser VALUES (3, 1, 2000);
INSERT INTO sponsoriser VALUES (4, 6, 3500);
INSERT INTO sponsoriser VALUES (4, 2, 3000);
INSERT INTO sponsoriser VALUES (4, 4, 1500);
INSERT INTO sponsoriser VALUES (5, 7, 2500);
INSERT INTO sponsoriser VALUES (5, 2, 2000);
INSERT INTO sponsoriser VALUES (6, 4, 3000);
INSERT INTO sponsoriser VALUES (6, 6, 3000);
INSERT INTO sponsoriser VALUES (7, 1, 2500);
INSERT INTO sponsoriser VALUES (7, 6, 2000);
INSERT INTO sponsoriser VALUES (8, 8, 6000);
INSERT INTO sponsoriser VALUES (8, 2, 4000);

-- Equipes (ids 1 a 3)
INSERT INTO equipe (nom_equipe, nom_projet, id_competition) VALUES ('GreenCoders', 'EcoTri', 1);
INSERT INTO equipe (nom_equipe, nom_projet, id_competition) VALUES ('ByteForce', 'SmartBin', 1);
INSERT INTO equipe (nom_equipe, nom_projet, score, id_competition) VALUES ('EduMinds', 'LearnUp', 16.5, 3);

-- Participants (ids 1 a 4)
INSERT INTO participant (nom, prenom, email, etablissement, niveau, competences, id_equipe)
  VALUES ('Mansouri', 'Amine', 'amine.mansouri@esprit.tn', 'ESPRIT', 'INTERMEDIAIRE', 'C++, Qt', 1);
INSERT INTO participant (nom, prenom, email, etablissement, niveau, competences, id_equipe)
  VALUES ('Khelifi', 'Sarra', 'sarra.khelifi@esprit.tn', 'ESPRIT', 'DEBUTANT', 'Design, Pitch', 1);
INSERT INTO participant (nom, prenom, email, etablissement, niveau, competences, id_equipe)
  VALUES ('Dridi', 'Omar', 'omar.dridi@esprit.tn', 'ESPRIT', 'AVANCE', 'IA, Python', 2);
INSERT INTO participant (nom, prenom, email, etablissement, niveau, competences, id_equipe)
  VALUES ('Saidi', 'Ines', 'ines.saidi@esprit.tn', 'ESPRIT', 'INTERMEDIAIRE', 'Web, JavaScript', 3);

-- Ateliers (ids 1 a 4)
INSERT INTO atelier (titre, categorie, date_heure, duree_minutes, capacite, statut, id_formateur, id_salle, id_competition)
  VALUES ('Introduction a Git et GitHub', 'Outils', TO_DATE('12/05/2025 09:00','DD/MM/YYYY HH24:MI'), 120, 30, 'PLANIFIE', 9, 5, 1);
INSERT INTO atelier (titre, categorie, date_heure, duree_minutes, capacite, statut, id_formateur, id_salle, id_competition)
  VALUES ('Pitch : convaincre un jury en 3 minutes', 'Soft skills', TO_DATE('13/05/2025 14:00','DD/MM/YYYY HH24:MI'), 90, 40, 'PLANIFIE', 10, 3, 1);
INSERT INTO atelier (titre, categorie, date_heure, duree_minutes, capacite, statut, id_formateur, id_salle, id_competition)
  VALUES ('Machine learning avec Python', 'Intelligence artificielle', TO_DATE('25/03/2025 10:00','DD/MM/YYYY HH24:MI'), 180, 25, 'TERMINE', 10, 5, 6);
INSERT INTO atelier (titre, categorie, date_heure, duree_minutes, capacite, statut, id_formateur, id_salle, id_competition)
  VALUES ('Interfaces graphiques avec Qt', 'Developpement', TO_DATE('15/07/2025 09:30','DD/MM/YYYY HH24:MI'), 150, 30, 'PLANIFIE', 9, 3, 7);

-- Inscriptions aux ateliers (present + code du certificat)
INSERT INTO inscription_atelier (id_participant, id_atelier, present, code_certificat) VALUES (1, 1, 'O', 'HT-CERT-2025-0001');
INSERT INTO inscription_atelier (id_participant, id_atelier, present, code_certificat) VALUES (2, 1, 'O', 'HT-CERT-2025-0002');
INSERT INTO inscription_atelier (id_participant, id_atelier, present) VALUES (2, 2, 'N');
INSERT INTO inscription_atelier (id_participant, id_atelier, present, code_certificat) VALUES (3, 3, 'O', 'HT-CERT-2025-0003');
INSERT INTO inscription_atelier (id_participant, id_atelier, present) VALUES (4, 4, 'N');

-- Affectations des employes (charge de travail)
INSERT INTO affectation (id_employe, id_competition, tache, date_debut, date_fin, nb_heures)
  VALUES (2, 1, 'Coordination generale', TO_DATE('12/05/2025','DD/MM/YYYY'), TO_DATE('14/05/2025','DD/MM/YYYY'), 24);
INSERT INTO affectation (id_employe, id_competition, tache, date_debut, date_fin, nb_heures)
  VALUES (2, 2, 'Accueil des equipes', TO_DATE('20/05/2025','DD/MM/YYYY'), TO_DATE('22/05/2025','DD/MM/YYYY'), 20);
INSERT INTO affectation (id_employe, id_competition, tache, date_debut, date_fin, nb_heures)
  VALUES (9, 1, 'Support technique', TO_DATE('12/05/2025','DD/MM/YYYY'), TO_DATE('14/05/2025','DD/MM/YYYY'), 18);
INSERT INTO affectation (id_employe, id_competition, tache, date_debut, date_fin, nb_heures)
  VALUES (12, 4, 'Planning du staff', TO_DATE('10/06/2025','DD/MM/YYYY'), TO_DATE('12/06/2025','DD/MM/YYYY'), 12);

COMMIT;

-- ---------------------------------------------------------------------
-- 4. Verification
-- ---------------------------------------------------------------------
SELECT table_name FROM user_tables ORDER BY table_name;
SELECT (SELECT COUNT(*) FROM competition) AS nb_competitions,
       (SELECT COUNT(*) FROM atelier)     AS nb_ateliers,
       (SELECT COUNT(*) FROM employe)     AS nb_employes
FROM dual;
