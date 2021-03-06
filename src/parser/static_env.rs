use std::collections::HashSet;

pub struct StaticEnv {
    variables: HashSet<String>,
    stack: Vec<HashSet<String>>,
}

impl StaticEnv {
    //     def reset
    //       @variables = Set[]
    //       @stack     = []
    //     end
    pub fn new() -> StaticEnv {
        StaticEnv {
            variables: HashSet::new(),
            stack: vec![],
        }
    }

    //     def extend_static
    //       @stack.push(@variables)
    //       @variables = Set[]
    // 
    //       self
    //     end
    // TODO NOTE
    pub fn extend_static(&mut self) {
        println!("static_env: extend_static");

        // TODO PERFORMANCE i don't think this clone is necessary
        let variables = self.variables.clone();
        self.stack.push(variables);
        self.variables = HashSet::new();
    }

    //     def extend_dynamic
    //       @stack.push(@variables)
    //       @variables = @variables.dup
    // 
    //       self
    //     end
    pub fn extend_dynamic(&mut self) {
        println!("static_env: extend_dynamic");

        self.stack.push(self.variables.clone());
    }

    //     def unextend
    //       @variables = @stack.pop
    // 
    //       self
    //     end
    pub fn unextend(&mut self) {
        println!("static_env: unextend");

        self.variables = self.stack.pop().unwrap();
    }

    //     def declare(name)
    //       @variables.add(name.to_sym)
    // 
    //       self
    //     end
    pub fn declare(&mut self, name: String) {
        println!("static_env: declare, name: {}", name);

        self.variables.insert(name);
    }

    //     def declared?(name)
    //       @variables.include?(name.to_sym)
    //     end
    pub fn has_declared(&self, name: &String) -> bool {
        println!("static_env: has_declared, name: {}", name);

        self.variables.contains(name)
    }
}
