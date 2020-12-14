# Aλonzo

Welcome to Aλonzo (an homage to [Alonzo Church](https://en.wikipedia.org/wiki/Alonzo_Church)), a CLI implementation the untyped [λ-calculus](https://en.wikipedia.org/wiki/Lambda_calculus) implemented in [Elixir](https://elixir-lang.org/). It allows you to input arbitrary λ-terms and then finds its β-normal form, if the term has one.

### The Syntax

First, here's a list of valid terms, so you can get an idea:

```
λx.x y
λx.(x y)
λx y.a x y
λx.λy.a x y
(λx.x x) x'
(var1)(var2)
```

More generally:

- **Variables**: start with a lowercase Latin letter, followed by arbitrary sequences of (any-case) Latin letters, numbers, apostrophes `'`, and underscores `_`
- **Parentheses**: may surround any sub-term, but are not required unless they are "logically required", e.g. for `x (y z)` or `(λx.x)y`
- **Spaces**: separate two variables, but are not required and simply ignored in all other cases
- **Lambdas**: can be typed as `λ`, `\`, or `&`, whatever is most convenient

### β-Reduction and α-conversion

After typing a term, β-reduction steps are performed by contracting the left-most redex. This stops after:

- a β-normal form is found, i.e. the term has no redex
- the term reduces to itself, e.g. for `(λx.x x)(λx.x x)`
- 5000 beta-steps, or if the left-most redex is nested under 1000 applications and/or abstractions, as hard limits, since β-reduction does not necessarily terminate

Before contracting a redex, α-conversion is performed on this redex (only), if necessary, as this suffices to avoid the capture of variables. This is done by appending apostrophes `'` to bound variables.

Here's an example:

```
λ$ (\x y.x y) y
λ> ((λx y.(x y)) y)
α> ((λx y'.(x y')) y)
β> (λy'.(y y'))
```

Note on the CLI: `λ$` precede input prompts, `λ>` the fully-parenthesised version of the given term, and `α>` and `β>` precede the results of α-conversion and β-reduction steps, respectively.

### Metavariables

Metavariables allow you to abbreviate terms. They start with either a uppercase Latin letter or a colon `:`, followed by arbitrary sequences of (any-case) Latin letters, numbers, apostrophes `'`, and underscores `_`. They can be declared either in a `metavars.txt`-file within the directory of execution, or within the CLI by beginning a line with `!`, e.g.:

```
λ$ ! :om = (\x.x x)
λ> :om ≡ (λx.(x x))
λ$ ! Om = :om :om
λ> Om ≡ ((λx.(x x)) (λx.(x x)))
```

Quitting the CLI by `Ctrl`+`D` instead of `Ctrl`+`C` creates a `metavars.txt`-file, saving the current metavariable declarations.

Metavariables are also re-replaced into terms as a last step when reducing terms:

```
λ$ a ((\x y.y y) b)
λ> (a ((λx y.(y y)) b))
β> (a (λy.(y y)))
≡  (a :om)
```

This is done by internally converting terms into _de Bruijn index_ representations and comparing sub-terms to the current set of metavariables.

### Church Encodings

Natural Numbers are treated as special metavariables and are internally represented by Church numerals:

```
λ$ 3
λ> (λf x.(f (f (f x))))
≡  3
```

There are also Church encodings of basic arithmetic operators:

```
λ$ ! Mult = \x y z.(x (y z))
λ> Mult ≡ (λx y z.(x (y z)))
λ$ Mult 2 3
λ> (((λx y z.(x (y z))) (λf x.(f (f x)))) (λf x.(f (f (f x)))))
β> [...]
β> (λz x'.(z (z (z (z (z (z x')))))))
≡  6
```

### Factorial

Here's an implementation of the factorial function, using the [Y-combinator](https://en.wikipedia.org/wiki/Fixed-point_combinator#Fixed-point_combinators_in_lambda_calculus):

`metavars.txt`:

```
True = (λx y.x)
False = (λx y.y)
Mult = (λx y z.(x (y z)))
Pred = (λn f x.(((n (λg h.(h (g f)))) (λu.x)) (λu.u)))
IfIsZero = (λn.((n (λz x y.y)) (λx y.x)))
Y = (λf.((λx.(f (x x))) (λx.(f (x x)))))
FACT = (λf x. IfIsZero (x) (1) ( Mult (x) (f (Pred x)) ))
```

(Beginning a line with a semicolon `;` hides all β-steps but the last, making it run a little quicker.)

```
λ$ ; Y FACT 4
λ> (((λf.((λx.(f (x x))) (λx.(f (x x))))) (λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x)))))) (λf x.(f (f (f (f x))))))
β> (λz' x'''.(z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' x''')))))))))))))))))))))))))
≡  24
```

On my machine, this takes 5 seconds. It takes a little longer without the `;`, but it looks interesting to watch the computation. :D

`Y FACT 5` exceeds the hard limit for the number of β-steps, but even without limits, it took longer than I wanted to wait. It should be no surprise that this implementation isn't exactly efficient, but it does work in principle.

## Installation and usage

See https://elixir-lang.org/install.html for how to install Elixir. To execute the CLI, you really only need `esl-erlang`, but I do recommend checking out Elixir; it's an awesome language!

I also recommend installing `rlwrap`: have you ever wanted to use the arrow keys in a CLI and only got `^[[D` etc.? `rlwrap` fixes that. Simply run `sudo apt-get install rlwrap`.

Then either clone this repository, or just download the `alonzo` file in the root directory. You will probably need to `chmod +x alonzo`.

Then simply type `rlwrap ./alonzo` and you're good to go. You can also specify a file containing the metavariable declarations (defaults to `metavars.txt`), i.e. `rlwrap ./alonzo metavars_arith.txt`. `Ctrl`+`D` will always save to `metavars.txt`, though!

Code quality disclaimer: My code is currently undocumented and, while not a complete mess, not really nice to look at. I might change that at some point, but for now, open it at your own risk.

If you want to make changes anyway, you can compile the program by running `mix escript.build`.