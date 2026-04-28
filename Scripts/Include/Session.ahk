class Session {
    sessionItems := {}
    
    __New(){
        this.sessionItems := {}
    }

    set(itemName, itemValue){
        this.sessionItems[itemName] := itemValue
    }

    get(itemName){
        return this.sessionItems[itemName]
    }
}