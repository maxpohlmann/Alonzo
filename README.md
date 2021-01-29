# Aλonzo

Welcome to Aλonzo ([Alonzo](https://en.wikipedia.org/wiki/Alonzo_Church)), an interpreter for the (untyped) [λ-calculus](https://en.wikipedia.org/wiki/Lambda_calculus) implemented in [Elixir](https://elixir-lang.org/), in the form of a [CLI](https://en.wikipedia.org/wiki/Command-line_interface). It allows you to input arbitrary λ-terms and then finds its β-normal form, if the term has one. It can also infer types ([simply typed](https://en.wikipedia.org/wiki/Simply_typed_lambda_calculus), Curry-style) of terms, if the term is typable.

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

- **Variables** start with a lowercase Latin letter, followed by arbitrary sequences of (any-case) Latin letters, numbers, apostrophes `'`, and underscores `_`
- **Parentheses** may surround any sub-term, but are not required unless they are "logically required", e.g. for `x (y z)` or `(λx.x)y`
- **Spaces** separate two variables, but are not required and simply ignored in all other cases
- **Lambdas** can be typed as `λ`, `\`, or `&`, whatever is most convenient

### β-Reduction and α-conversion

After typing a term, β-reduction steps are performed by contracting the left-most redex. This stops after:

- a β-normal form is found, i.e. the term has no redex
- the term reduces to itself, e.g. for `(λx.x x)(λx.x x)`
- 5000 β-steps, or if the left-most redex is nested under 1000 applications and/or abstractions, as hard limits, since β-reduction does not necessarily terminate

Before contracting a redex, α-conversion is performed on this redex (only), if necessary, as this suffices to avoid the capture of variables. This is done by appending apostrophes `'` to bound variables.

Here's an example:

```
λ$ (\x y.x y) y
λ> ((λx y.(x y)) y)
α> ((λx y'.(x y')) y)
β> (λy'.(y y'))
```

Note on the CLI lines: `λ$` precedes input prompts, `λ>` the fully-parenthesised version of the given term, and `α>` and `β>` precede the results of α-conversion and β-reduction steps, respectively.

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

This is done by internally converting terms into [de Bruijn index](https://en.wikipedia.org/wiki/De_Bruijn_index) representations and comparing sub-terms to the current set of metavariables.

Metavariables also implement α-conversion:

```
λ$ \x.(:om)
λ> (λx x'.(x' x'))
≡  (λx.:om)
```

### [Church Encodings](https://en.wikipedia.org/wiki/Church_encoding)

Natural Numbers are treated as special metavariables and are internally represented by Church numerals:

```
λ$ 3
λ> (λf x.(f (f (f x))))
≡  3
```

There are also Church encodings of basic arithmetic operators, e.g.:

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
Y = (λf.((λx.(f (x x))) (λx.(f (x x)))))
IfIsZero = (λn.n (True False) True)
FACT = (λf x. IfIsZero (x) (1) ( Mult (x) (f (Pred x)) ))
```

(Beginning a line with a semicolon `;` hides all β-steps but the last, making it run a little quicker.)

```
λ$ ; Y FACT 4
λ> (((λf.((λx.(f (x x))) (λx.(f (x x))))) (λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x)))))) (λf x.(f (f (f (f x))))))
β> (λz' x'''.(z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' (z' x''')))))))))))))))))))))))))
≡  24
```

On my machine, this takes 5 seconds. It takes a little longer without the `;`, but it looks interesting to watch the computation (see below). :D

`Y FACT 5` exceeds the hard limit for the number of β-steps, but even without limits, it took longer than I wanted to wait. It should be no surprise that this implementation isn't exactly efficient, but it does work in principle.



## Simply typed lambda calculus (type inference à la Curry)

Begin a line with `?` to determine the most general type (more precisely, the principal pair) of the term. Right now, all type variables are wildly numbered αs, but I'd like to make that look nicer at some point. Some examples (for predefined metavariables):

```
λ$ ? S
λ>  ⊢ (λx y z.((x z) (y z))) : ((α5 → (α7 → α6)) → ((α5 → α7) → (α5 → α6)))
λ$ ? K
λ>  ⊢ (λx y.x) : (α1 → (α3 → α1))
λ$ ? I
λ>  ⊢ (λx.x) : (α1 → α1)
λ$ ? S K
λ>  ⊢ ((λx y z.((x z) (y z))) (λx y.x)) : ((α6 → α8) → (α6 → α6))
λ$ ? K I
λ>  ⊢ ((λx y.x) (λx.x)) : (α4 → (α6 → α6))
λ$ ? Y
λ>  ⊢ (λf.((λx.(f (x x))) (λx.(f (x x))))) : untypable
λ$ ? I a
λ> a:α1 ⊢ ((λx.x) a) : α1
```



## Installation and usage

(Only tested on Linux Ubuntu)

See https://elixir-lang.org/install.html for how to install Elixir. To execute the CLI, you really only need `esl-erlang`, but I do recommend checking out Elixir; it's an awesome language!

I also recommend installing `rlwrap`: have you ever wanted to use the arrow keys in a CLI and only got `^[[D` etc.? `rlwrap` fixes that. Simply run `sudo apt-get install rlwrap`.

Then either clone this repository, or just download the `alonzo` file in the root directory (and optionally some `metavars.txt`). You will probably need to `chmod +x alonzo`.

Then simply type `rlwrap ./alonzo` and you're good to go. You can also specify a file containing the metavariable declarations (defaults to `metavars.txt`), i.e. `rlwrap ./alonzo metavars_arith.txt`. `Ctrl`+`D` will always save to `metavars.txt`, though!

Code quality disclaimer: My code is currently undocumented and, while not a complete mess, not really nice to look at. I might refactor and document it at some point, but for now, look at it at your own risk.

If you want to make changes anyway, you can compile the program by running `mix escript.build`.


## Some More Examples

### ω 1

```
λ$ :om 1
λ> ((λx.(x x)) (λf x.(f x)))
β> ((λf x.(f x)) (λf x.(f x)))
α> ((λf x'.(f x')) (λf x.(f x)))
β> (λx'.((λf x.(f x)) x'))
β> (λx' x.(x' x))
≡  1
```


### Multiplication

```
λ$ Mult 3 4
λ> (((λx y z.(x (y z))) (λf x.(f (f (f x))))) (λf x.(f (f (f (f x))))))
β> ((λy z.((λf x.(f (f (f x)))) (y z))) (λf x.(f (f (f (f x))))))
α> ((λy z.((λf' x'.(f' (f' (f' x')))) (y z))) (λf x.(f (f (f (f x))))))
β> (λz.((λf' x'.(f' (f' (f' x')))) ((λf x.(f (f (f (f x))))) z)))
β> (λz x'.(((λf x.(f (f (f (f x))))) z) (((λf x.(f (f (f (f x))))) z) (((λf x.(f (f (f (f x))))) z) x'))))
β> (λz x'.((λx.(z (z (z (z x))))) (((λf x.(f (f (f (f x))))) z) (((λf x.(f (f (f (f x))))) z) x'))))
β> (λz x'.(z (z (z (z (((λf x.(f (f (f (f x))))) z) (((λf x.(f (f (f (f x))))) z) x')))))))
β> (λz x'.(z (z (z (z ((λx.(z (z (z (z x))))) (((λf x.(f (f (f (f x))))) z) x')))))))
β> (λz x'.(z (z (z (z (z (z (z (z (((λf x.(f (f (f (f x))))) z) x'))))))))))
β> (λz x'.(z (z (z (z (z (z (z (z ((λx.(z (z (z (z x))))) x'))))))))))
β> (λz x'.(z (z (z (z (z (z (z (z (z (z (z (z x')))))))))))))
≡  12
```


### Factorial

```
λ$ Y FACT 1
λ> (((λf.((λx.(f (x x))) (λx.(f (x x))))) (λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x)))))) (λf x.(f x)))
α> (((λf.((λx''.(f (x'' x''))) (λx''.(f (x'' x''))))) (λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x)))))) (λf x.(f x)))
β> (((λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x''))) (λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x'')))) (λf x.(f x)))
α> (((λx''.((λf'' x'''.((((λn'.((n' (λz' x'''' y'.y')) (λx'''' y'.x''''))) x''') (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) x''') (f'' ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) x'''))))) (x'' x''))) (λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x'')))) (λf x.(f x)))
β> (((λf'' x'''.((((λn'.((n' (λz' x'''' y'.y')) (λx'''' y'.x''''))) x''') (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) x''') (f'' ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) x'''))))) ((λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x''))) (λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x''))))) (λf x.(f x)))
β> ((λx'''.((((λn'.((n' (λz' x'''' y'.y')) (λx'''' y'.x''''))) x''') (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) x''') (((λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x''))) (λx''.((λf x.((((λn.((n (λz x' y.y)) (λx' y.x'))) x) (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x) (f ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) x'''))))) (λf x.(f x)))
α> ((λx'''.((((λn'.((n' (λz' x'''' y'.y')) (λx'''' y'.x''''))) x''') (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) x''') (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) x'''))))) (λf x.(f x)))
β> ((((λn'.((n' (λz' x'''' y'.y')) (λx'''' y'.x''''))) (λf x.(f x))) (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
β> (((((λf x.(f x)) (λz' x'''' y'.y')) (λx'''' y'.x'''')) (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
β> ((((λx.((λz' x'''' y'.y') x)) (λx'''' y'.x'''')) (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
α> ((((λx.((λz' x''''' y''.y'') x)) (λx'''' y'.x'''')) (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
β> ((((λz' x''''' y''.y'') (λx'''' y'.x'''')) (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
β> (((λx''''' y''.y'') (λf''' x''''.(f''' x''''))) (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
β> ((λy''.y'') (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))
β> (((λx'''' y' z'.(x'''' (y' z'))) (λf x.(f x))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))))
β> ((λy' z'.((λf x.(f x)) (y' z'))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))))
α> ((λy' z'.((λf'''' x'''.(f'''' x''')) (y' z'))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))))
β> (λz'.((λf'''' x'''.(f'''' x''')) ((((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) z')))
β> (λz' x'''.(((((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) z') x'''))
α> (λz' x'''.(((((λx''.((λf''' x''''''.((((λn'.((n' (λz' x''' y'.y')) (λx''' y'.x'''))) x'''''') (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) x'''''') (f''' ((λn' f'''' x'''.(((n' (λg' h'.(h' (g' f'''')))) (λu'.x''')) (λu'.u'))) x''''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) z') x'''))
β> (λz' x'''.(((((λf''' x''''''.((((λn'.((n' (λz' x''' y'.y')) (λx''' y'.x'''))) x'''''') (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) x'''''') (f''' ((λn' f'''' x'''.(((n' (λg' h'.(h' (g' f'''')))) (λu'.x''')) (λu'.u'))) x''''''))))) ((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) z') x'''))
β> (λz' x'''.((((λx''''''.((((λn'.((n' (λz' x''' y'.y')) (λx''' y'.x'''))) x'''''') (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) x'''''') (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn' f'''' x'''.(((n' (λg' h'.(h' (g' f'''')))) (λu'.x''')) (λu'.u'))) x''''''))))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) z') x'''))
α> (λz' x'''.((((λx''''''.((((λn''.((n'' (λz' x''' y'.y')) (λx''' y'.x'''))) x'''''') (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) x'''''') (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) x''''''))))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) z') x'''))
β> (λz' x'''.((((((λn''.((n'' (λz' x''' y'.y')) (λx''' y'.x'''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((((((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))) (λz' x''' y'.y')) (λx''' y'.x''')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.(((((((λf''' x''''.((((λf x.(f x)) (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λz' x''' y'.y')) (λx''' y'.x''')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((((λx''''.((((λf x.(f x)) (λg' h'.(h' (g' (λz' x''' y'.y'))))) (λu'.x'''')) (λu'.u'))) (λx''' y'.x''')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
α> (λz' x'''.((((((λx''''.((((λf x.(f x)) (λg' h'.(h' (g' (λz' x''''' y''.y''))))) (λu'.x'''')) (λu'.u'))) (λx''' y'.x''')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((((((λf x.(f x)) (λg' h'.(h' (g' (λz' x''''' y''.y''))))) (λu' x''' y'.x''')) (λu'.u')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.(((((((λx.((λg' h'.(h' (g' (λz' x''''' y''.y'')))) x)) (λu' x''' y'.x''')) (λu'.u')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.(((((((λg' h'.(h' (g' (λz' x''''' y''.y'')))) (λu' x''' y'.x''')) (λu'.u')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((((λh'.(h' ((λu' x''' y'.x''') (λz' x''''' y''.y'')))) (λu'.u')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
α> (λz' x'''.((((((λh'.(h' ((λu'' x''' y'.x''') (λz' x''''' y''.y'')))) (λu'.u')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((((λu'.u') ((λu'' x''' y'.x''') (λz' x''''' y''.y''))) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((((λu'' x''' y'.x''') (λz' x''''' y''.y'')) (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.(((((λx''' y'.x''') (λf'''' x'''.(f'''' x'''))) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.((((λy' f'''' x'''.(f'''' x''')) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
α> (λz' x'''.((((λy' f''''' x''''''.(f''''' x'''''')) (((λx''' y' z'.(x''' (y' z'))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x)))) (((λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x''))) (λx''.((λf'' x'''''.((((λn.((n (λz x' y.y)) (λx' y.x'))) x''''') (λf' x'.(f' x'))) (((λx' y z.(x' (y z))) x''''') (f'' ((λn f' x'.(((n (λg h.(h (g f')))) (λu.x')) (λu.u))) x'''''))))) (x'' x'')))) ((λn'' f'''' x'''.(((n'' (λg'' h''.(h'' (g'' f'''')))) (λu''.x''')) (λu''.u''))) ((λn' f''' x''''.(((n' (λg' h'.(h' (g' f''')))) (λu'.x'''')) (λu'.u'))) (λf x.(f x))))))) z') x'''))
β> (λz' x'''.(((λf''''' x''''''.(f''''' x'''''')) z') x'''))
β> (λz' x'''.((λx''''''.(z' x'''''')) x'''))
β> (λz' x'''.(z' x'''))
≡  1
```

[Y FACT 2](./factorial_2.txt)

[Y FACT 3](./factorial_3.txt)

[Y FACT 4](./factorial_4.txt)
