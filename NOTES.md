ZMIANY, PROPOZYCJE ROZWOJU, ZAŁOŻENIA, OGRANICZENIA

PLIK: full_pipeline.sv
1. synchroniczny reset może powodować takie niekorzystane zajwiska jak:
-zjawisko metastabilności,
-brak działania resetu bez zegara,
-dodatkowa logika kombinacyjna oznacza zmniejszenie maksymalnej częstotliwości pracy,
-filtrowanie zbyt krótkich impulsów,
-w celu ulepszenia proponuje się zastosowanieresetu asynchronicznego sterowanego zerem.

2. Bufor danych 1-rejestr
-dodanie sygnałów rozszerzających możliwści AXI4-Stream,
-ograniczenia czasowe s_ready oraz s_valid wraz z tb, możliwe problemy z metastabilnością w rzeczywistym układzie
-przy projektowaniu układu z tylko jednym rejestrem na dane ograniczeniem staje się liczba cykli. Zastosowanie synchronicznego układu oraz zasady handshake po obu stronach powoduje że przepustowość zmniejsza się dwukrotnie.
Następuje potrzeba by chwili s_valid=1 i s_ready przy nastepnym zbocznu zegara ustawić m_valid odraz odczytać m_ready by moć przekazać odczytaną daną do układu podrzędnego.
Dopiero przy drukiem takcie zegara gdy po odczytaniu danych ustawiony zostaje sygnał s_ready=1 odczytywnane do dut są następne dane które czekają już drugi tak zegara
Jednocześnie należy zauważyć że nie można ustawić jednocześnie s_ready=1 oraz m_valid = 1 gdyż to oznacza że bufor danych jest zarówno pełny jak i pusty w tym samym momencie.
Możliwym rozwiązaniem powyższego problemu jest zastosowanie 2 elementowego FIFO.

-sygnały valid oraz ready są generowane wewnętrznie w zalezności od rejestru data_reg,
-przestrzegane są zasady handshake po obu stronach,

PLIK: tb_full_pipeline.sv
1. send()
-możliwe problemy z metastbilnością podczas zmiany s_ready 0 -> 1 po pętli while. Sygnał s_valid <= 0 jest zmieniany na niski stan. 
Jesli nastąpi problem czasowy to gdy ponownie s_ready=1 oraz układ zdąży złapać jeszcze s_valid = 1 przed zmianą, może nastąpić nieporządane działanie układu. 
Proponowane rozwiązanie jak w/w to rozbicie działania układu na dwa cykle.

2. scoreboard

PLIK: analyze.py







1. JAK DZIAŁA PROJEKT I DLACZEGO POTRZEBUJE UŻYTYCH REJESTRÓW
Projekt implementuje potok danych valid/ready w module rtl/full_pipeline.sv

Głównym założeniem jest rozdzielenie strony wejściowej i wyjściowej rejestrem przechowującym jedno słowo danych. Rejestr pełni jednocześnie rolę jednopoziomowego bufora:
-s_valid - układ nadrzędny oferuje ważne dane,
-s_ready - moduł może przyjąć dane,
-m_valid - w buforze znajduje się ważne słowo,
-m_ready - układ podrzędny może przyjąć dane.

Transfer zachodzi wyłącznie wtedy, gdy odpowiednia para valid/ready jest równocześnie równa 1.
Po resecie valid jest wyzerowany, więc moduł nie przedstawa na wyjściu żadnych danych jako ważnych.

Potok wykorzystuje rejestr danych oraz odpowiadający mu bit valid.

Rejestr jest potrzebny przede wszystkim dlatego, że wymagania zabraniają bezpośredniej kombinacyjnej ścieżki od wejścia do wyjścia. Dzięki rejestrowaniu danych:
-dane wejściowe są próbkowane na zboczu zegara,
-pozostają stabilne podczas oczekiwania na m_ready,
-wyjście może być zatrzymane przez dowolną liczbę cykli backpressure,
-zmiana dnaych wejściowych nie wpływa bezpośrednio na m_data.

W przypadku jednego poziomu buforowania moduł może przyjąć nowe dane, gdy poprzednie dane zostały odebrane albo bufor jest pusty.

Obsługa handshake:

s_valid && s_ready - transfer wejściowy jest uznawany za wykonany,
m_valid && m_ready - transfer wyjściowy jest uznawany za wykonany,

Jeżeli m_valid=1 oraz m_ready=0, dane pozostają w rejestrze i nie mogą zostać nadpisane. Jest to kluczowe dla poprawnej obsługi backpressure.

Testbench sprawdza, czy słowa wychodzą w tej samej kolejności w której zostały zaakcpetowane na wejściu.

2. ISTOTNE ZAŁOŻENIA i DECYZJE PROJEKTOWE
Założenia:
-reset jest synchronicnzy i aktywny stanem wysokim,
-reset występuje tylko na początku symulacji,
-nie są używane dodatkowe sygnały AXI4-Stream, takie jak TLAT czy TKEEP,
-nie jest używany gotowy FIFO,
-rozwiązanie jest syntezowane i nie wymaga formalnej weryfikacji
-brak założenia że m_ready jest zawsze aktywne, moduł musi zachowywać dane jeśli m_ready=0.


3. WYNIK make test I CO ON MOWI O PROJEKCIE
Przykładowy wynik po ukończeniu implementacji:




Rzeczywisty wynik zależy od wersji implementacji, liczby słów oraz parametrów losowych.

Przed implementacją sen(), dostraczony testbench kończył się timeoutem, co jest zachowaniem oczekiwanym przez opis zadania.

Skrypt scripts/analyze.py przetwarza build/sink.txt.

Dla każdej fazy raportowane są:
-liczba słów zaakceptowyanych na wejściu,
-liczba słów odebranych na wyjściu,
-przepustowość w słowach/cykl,
-opóźnienie pierwszego słowa,
-liczba cykli związnaych z backpressure.

Dodatkowo sprawdzana jest poprawność handshake oraz zgodność sekwencji dnaych pomiędzy wejściem i wyjściem.

Kod 0 oznacza poprawną analizę, natomiast 1 oznacza wykrycie błędu.

4. ZMIANY W DOSTARCZONYCH PLIKACH
-rtl/full_pipeline.sv - zastąpienie kominacyjnego placeholdera zarejestrowanym buforem valid/data,
-tb/tb_full_pipeline.sv - implementacja sen(0 oraz scoreboard,
-scripts/analyze.py - dodane obsługi pliku sink.txt, odczyt danych oraz metryk, kontrola protokołu, zaimplementowanie obsługi błędów.
-NOTES.md - dokumentacja decyzji projektowych i wyników.

5. OGRANICZENIA I MOŻLIWE USPRAWNIENIA
Należy rozważyć:
-bardziej rozbudowane testy graniczne,
-testy z różnymi ziarnami generatora,
-dodanie modułów UVM (monitor, interface)

