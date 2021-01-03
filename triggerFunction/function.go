// Package p contains a Pub/Sub Cloud Function.
package p

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	cloudbilling "google.golang.org/api/cloudbilling/v1"
)

// BillingBudgetAlert is the message published by budget alert
type BillingBudgetAlert struct {
	CostAmount   float64 `json:"costAmount"`
	BudgetAmount float64 `json:"budgetAmount"`
}

// PubSubMessage is the payload of a Pub/Sub event. Please refer to the docs for
// additional information regarding Pub/Sub events.
type PubSubMessage struct {
	Data []byte `json:"data"`
}

// Trigger consumes a Pub/Sub message.
func Trigger(ctx context.Context, m PubSubMessage) error {
	log.Println(string(m.Data))
	var budgetMsg BillingBudgetAlert
	json.Unmarshal(m.Data, &budgetMsg)
	log.Printf("Cost Amount: %f, Budget Amount: %f", budgetMsg.CostAmount, budgetMsg.BudgetAmount)

	cloudbillingService, err := cloudbilling.NewService(ctx)
	if err != nil {
		return err
	}
	log.Println("cloud billing service client created")

	cloudbillingProjectService := cloudbilling.NewProjectsService(cloudbillingService)
	log.Println("cloud billing project client created")

	if budgetMsg.CostAmount >= budgetMsg.BudgetAmount {
		log.Println("Budget limit exceeded. Billing Account will be disabled for this project.")
		infoUpdateCall := cloudbillingProjectService.UpdateBillingInfo(fmt.Sprintf("projects/%s", os.Getenv("PROJECT_ID")), &cloudbilling.ProjectBillingInfo{
			BillingAccountName: "",
			Name:               fmt.Sprintf("projects/%s/billingInfo", os.Getenv("PROJECT_ID")),
			ProjectId:          os.Getenv("PROJECT_ID"),
			BillingEnabled:     false,
		})

		_, err := infoUpdateCall.Do()
		if err != nil {
			return err
		}
	}

	return nil
}
